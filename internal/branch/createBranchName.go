package branch

import (
	"fmt"
	"strings"

	"github.com/iancoleman/strcase"
	configPkg "github.com/paulbaernreuther/ai-framework/internal/config"
)

type CreateBranchNameConfig struct {
	// Optional AI-powered slug generators
	// (e.g. Claude, Copilot) that race to produce a better branch slug.
	AdditionalBranchNameCreators []BranchNameCreator
	// E.g. 70 (used at KNIME)
	MaxBranchNameLength int
	PossiblePrefixes    []string // e.g. ["enh", "fix", "todo"]
}

type BranchNameCreator struct {
	Name       string
	CreateName func(name string, maxLength int) (string, error)
}

// CleanSlug strips non-slug characters, lowercases, trims dashes, and truncates.
func CleanSlug(raw string, maxLength int) string {
	slug := strings.ToLower(strings.TrimSpace(raw))
	var b strings.Builder
	for _, c := range slug {
		if (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-' {
			b.WriteRune(c)
		}
	}
	slug = strings.Trim(b.String(), "-")
	if len(slug) > maxLength {
		slug = slug[:maxLength]
	}
	return strings.TrimRight(slug, "-")
}

var defaultBranchNameCreator = BranchNameCreator{
	Name: "Default",
	CreateName: func(name string, maxLength int) (string, error) {
		return CleanSlug(strcase.ToKebab(name), maxLength), nil
	},
}

type CreateBranchNameConfigWithBase struct {
	configPkg.BaseConfig
	CreateBranchNameConfig
}

func NewCreateBranchNameConfig(base configPkg.BaseConfig, cbnc CreateBranchNameConfig) CreateBranchNameConfigWithBase {
	return CreateBranchNameConfigWithBase{
		BaseConfig:             base,
		CreateBranchNameConfig: cbnc,
	}
}

// Builds a full branch name like "enh/UIEXT-1234-some-slug".
func CreateBranchName(config CreateBranchNameConfigWithBase, key string, name string, ticketType string) (branchSlug string, err error) {
	prefix, err := config.Pick(fmt.Sprintf("Choose a prefix for ticket type \"%s\"", ticketType), configPkg.PickerOptions{
		Options: config.PossiblePrefixes,
		PickerCacheOptions: configPkg.PickerCacheOptions{
			PickerID:         "ticket-prefix",
			InputValue:       ticketType,
			RememberFilesDir: config.AppDir,
		},
	})
	if err != nil {
		return "", err
	}
	prefix += "/" + key + "-"

	prefixLength := len(prefix)
	maxSlugLength := config.MaxBranchNameLength - prefixLength

	// try with default creator first and ask for confirmation if additional creators are available
	branchSlug, _ = defaultBranchNameCreator.CreateName(name, maxSlugLength)

	confirm := "Confirm"
	additionalCreatorNames := []string{}
	if config.AdditionalBranchNameCreators != nil {
		for _, c := range config.AdditionalBranchNameCreators {
			additionalCreatorNames = append(additionalCreatorNames, c.Name)
		}
	}
	nonDeterministic := fmt.Sprintf("Use tool%s (%s) to suggest another",
		func() string {
			if len(additionalCreatorNames) > 1 {
				return "s"
			} else {
				return ""
			}
		}(), strings.Join(additionalCreatorNames, ", "))
	manual := "Choose manually"
	confirmationOptions := []string{confirm}
	if config.AdditionalBranchNameCreators != nil {
		confirmationOptions = append(confirmationOptions, nonDeterministic)
	}
	confirmationOptions = append(confirmationOptions, manual)
	for {
		pickerOptions := configPkg.PickerOptions{
			Options: confirmationOptions,
		}
		if len(additionalCreatorNames) > 0 {
			pickerOptions.TabOption = nonDeterministic
		}
		chosenOption, err := config.Pick(
			fmt.Sprintf("Branch name: %s", prefix+branchSlug),
			pickerOptions,
		)
		if err != nil {
			return "", err
		}
		if chosenOption == confirm {
			break
		} else if chosenOption == nonDeterministic {
			branchSlug, err = GetFastestAdditionalSuggestion(config, name, maxSlugLength)
			// never trust AI output
			branchSlug = CleanSlug(branchSlug, maxSlugLength)
			if err != nil {
				return "", err
			}
		} else if chosenOption == manual {
			branchSlug, err = config.Pick("Type the branch slug manually", configPkg.PickerOptions{})
			branchSlug = CleanSlug(branchSlug, maxSlugLength)
			if err != nil {
				return "", err
			}
			break
		}
	}
	branchName := prefix + branchSlug
	fmt.Fprintf(config.Print, "New branch name: %s\n", branchName)
	return branchName, nil
}

func GetFastestAdditionalSuggestion(config struct {
	configPkg.BaseConfig
	CreateBranchNameConfig
}, name string, maxSlugLength int) (string, error) {
	type result struct {
		slug        string
		creatorName string
		err         error
	}
	results := make(chan result, len(config.AdditionalBranchNameCreators))

	for _, creator := range config.AdditionalBranchNameCreators {
		go func(c BranchNameCreator) {
			slug, err := c.CreateName(name, maxSlugLength)
			results <- result{slug: slug, creatorName: c.Name, err: err}
		}(creator)
	}
	var best result
	for i := 0; i < len(config.AdditionalBranchNameCreators); i++ {
		res := <-results
		if res.err == nil {
			best = res
			break
		}
		fmt.Fprintf(config.Print, "Error from %s: %v\n", res.creatorName, res.err)
	}

	if best.slug == "" {
		return "", fmt.Errorf("Failed to get branch name from tools")
	} else {
		fmt.Fprintf(config.Print, "%s came up with a suggestion\n", best.creatorName)
	}
	return best.slug, nil
}

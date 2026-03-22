package config

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

var FzfPicker Picker = func(prompt string, opts PickerOptions) (string, error) {
	if opts.RememberFilesDir == "" && opts.PickerID != "" {
		return "", fmt.Errorf("PickerCacheOptions.PickerID provided without RememberFilesDir. Prompt: %s", prompt)
	}
	if opts.PickerID == "" && opts.InputValue != "" {
		return "", fmt.Errorf("PickerCacheOptions.InputValue provided without PickerID. Prompt: %s", prompt)
	}

	// If we have a PickerID, check for a cached association first
	if opts.InputValue != "" {
		cached, err := readAssociation(opts.RememberFilesDir, opts.PickerID, opts.InputValue)
		if err == nil && cached != "" {
			return cached, nil
		}
	}

	if len(opts.Options) == 0 {
		return fzfFreeText(prompt)
	}
	return fzfFromOptions(prompt, opts)
}

func fzfFreeText(prompt string) (string, error) {
	cmd := exec.Command("fzf", "--header", prompt, "--prompt", "> ", "--height=3", "--print-query")
	cmd.Stdin = strings.NewReader("")
	cmd.Stderr = os.Stderr
	out, _ := cmd.Output()
	query := strings.SplitN(string(out), "\n", 2)[0]
	query = strings.TrimSpace(query)
	if query == "" {
		return "", fmt.Errorf("no input provided")
	}
	return query, nil
}

func fzfFromOptions(prompt string, opts PickerOptions) (string, error) {
	options := opts.Options
	if opts.PickerID != "" {
		options = SortByMRU(mruPath(opts.RememberFilesDir, opts.PickerID), options)
	}

	fzfArgs := []string{"--prompt", prompt, "--height=~20", "--reverse"}
	if opts.TabOption != "" {
		fzfArgs = append(fzfArgs, "--bind", fmt.Sprintf("tab:become(echo '%s')", opts.TabOption))
	}
	cmd := exec.Command("fzf", fzfArgs...)
	cmd.Stdin = strings.NewReader(strings.Join(options, "\n"))
	cmd.Stderr = os.Stderr
	out, err := cmd.Output()
	if err != nil {
		return "", err
	}
	selected := strings.TrimSpace(string(out))

	// Remember the selection
	if opts.PickerID != "" {
		TouchMRU(mruPath(opts.RememberFilesDir, opts.PickerID), selected)
	}
	if opts.InputValue != "" {
		writeAssociation(opts.RememberFilesDir, opts.PickerID, opts.InputValue, selected)
	}

	return selected, nil
}

func mruPath(dir, pickerID string) string {
	return filepath.Join(dir, ".picker-mru", pickerID)
}

func associationPath(dir, pickerID string) string {
	return filepath.Join(dir, ".picker-assoc", pickerID)
}

// readAssociation looks up a cached pickerID+inputValue → selection.
func readAssociation(rememberFilesDir, pickerID, inputValue string) (string, error) {
	data, err := os.ReadFile(associationPath(rememberFilesDir, pickerID))
	if err != nil {
		return "", err
	}
	// Format: one "inputValue=selection" per line
	for _, line := range strings.Split(string(data), "\n") {
		parts := strings.SplitN(line, "=", 2)
		if len(parts) == 2 && parts[0] == inputValue {
			return parts[1], nil
		}
	}
	return "", fmt.Errorf("no association found")
}

// writeAssociation stores a pickerID+inputValue → selection mapping.
func writeAssociation(rememberFilesDir, pickerID, inputValue, selection string) {
	path := associationPath(rememberFilesDir, pickerID)
	os.MkdirAll(filepath.Dir(path), 0755)

	var lines []string
	if data, err := os.ReadFile(path); err == nil {
		for _, line := range strings.Split(strings.TrimSpace(string(data)), "\n") {
			parts := strings.SplitN(line, "=", 2)
			// Keep all lines except the one we're updating
			if len(parts) == 2 && parts[0] != inputValue && line != "" {
				lines = append(lines, line)
			}
		}
	}
	lines = append(lines, inputValue+"="+selection)

	os.WriteFile(path, []byte(strings.Join(lines, "\n")+"\n"), 0644)
}

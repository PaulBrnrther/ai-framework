package main

import (
	"errors"
	"fmt"
	"os/exec"
	"strings"

	"github.com/paulbaernreuther/ai-framework/internal/branch"
)

func slugPrompt(name string, maxLength int) string {
	return fmt.Sprintf(
		"Output ONLY a kebab-case slug of about 5 lowercase words (max %d chars) separated by hyphens. No explanation, no quotes, no backticks. Just the slug for this Jira title: %s",
		maxLength, name,
	)
}

func aiCreator(name string, args ...string) branch.BranchNameCreator {
	return branch.BranchNameCreator{
		Name: name,
		CreateName: func(ticketName string, maxLength int) (string, error) {
			prompt := slugPrompt(ticketName, maxLength)
			cmdArgs := make([]string, 0, len(args)+1)
			replaced := false
			for _, a := range args {
				if a == "{prompt}" {
					cmdArgs = append(cmdArgs, prompt)
					replaced = true
				} else {
					cmdArgs = append(cmdArgs, strings.ReplaceAll(a, "{prompt}", prompt))
				}
			}
			if !replaced {
				cmdArgs = append(cmdArgs, prompt)
			}
			cmd := exec.Command(cmdArgs[0], cmdArgs[1:]...)
			var stderr strings.Builder
			cmd.Stderr = &stderr
			out, err := cmd.Output()
			if stderr.Len() > 0 {
				return "", errors.New(stderr.String())
			}
			if err != nil {
				return "", err
			}
			return string(out), nil
		},
	}
}

var createBranchNameConfig = branch.CreateBranchNameConfig{
	MaxBranchNameLength: 70,
	PossiblePrefixes:    []string{"enh", "fix", "todo"},
	AdditionalBranchNameCreators: []branch.BranchNameCreator{
		aiCreator("Claude", "claude", "-p", "--model", "haiku", "--effort", "low"),
		aiCreator("Copilot", "copilot", "-p", "{prompt}", "--model", "gpt-5.4-mini", "-s"),
	},
}

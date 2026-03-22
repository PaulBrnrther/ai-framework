package branch

import (
	"bytes"
	"fmt"
	"strings"
	"testing"

	"github.com/paulbaernreuther/ai-framework/internal/config"
)

func TestCreateBranchName(t *testing.T) {

	possiblePrefixes := []string{"enh", "fix", "todo"}
	t.Run("branch name examples", func(t *testing.T) {
		cases := []struct {
			name       string
			key        string
			ticketName string
			ticketType string
			prefix     string
			maxLen     int
			want       string
		}{
			{
				name:       "bug fix",
				key:        "UIEXT-1234",
				ticketName: "Fix the koala bug",
				ticketType: "Bug",
				prefix:     "fix",
				maxLen:     70,
				want:       "fix/UIEXT-1234-fix-the-koala-bug",
			},
			{
				name:       "enhancement",
				key:        "UIEXT-999",
				ticketName: "Add new dialog widget",
				ticketType: "Enhancement",
				prefix:     "enh",
				maxLen:     70,
				want:       "enh/UIEXT-999-add-new-dialog-widget",
			},
			{
				name:       "truncates long names",
				key:        "UIEXT-1234",
				ticketName: "A very long ticket name that should be truncated",
				ticketType: "Bug",
				prefix:     "fix",
				maxLen:     30,
				want:       "fix/UIEXT-1234-a-very-long-tic",
			},
		}

		for _, tc := range cases {
			t.Run(tc.name, func(t *testing.T) {
				mock := config.NewMockPicker(t,
					// First call: pick prefix
					config.PickerExpectation{
						Prompt:   "Choose a prefix for ticket type \"" + tc.ticketType + "\"",
						Options:  possiblePrefixes,
						Response: tc.prefix,
					},
					// Second call: confirm branch name
					config.PickerExpectation{
						Prompt:   "Branch name: " + tc.want,
						Response: "Confirm",
					},
				)
				defer mock.AssertDone()

				cfg := CreateBranchNameConfigWithBase{
					BaseConfig: config.BaseConfig{
						Pick:   mock.AsPicker(),
						Print:  &bytes.Buffer{},
						AppDir: t.TempDir(),
					},
					CreateBranchNameConfig: CreateBranchNameConfig{
						PossiblePrefixes:    possiblePrefixes,
						MaxBranchNameLength: tc.maxLen,
					},
				}

				got, err := CreateBranchName(cfg, tc.key, tc.ticketName, tc.ticketType)
				if err != nil {
					t.Fatalf("CreateBranchName failed: %v", err)
				}

				if tc.want != "" && got != tc.want {
					t.Errorf("got %q, want %q", got, tc.want)
				}
				if len(got) > tc.maxLen {
					t.Errorf("branch name too long: %d chars, want max %d: %q", len(got), tc.maxLen, got)
				}
			})
		}
	})

	t.Run("prints that the branch name was chosen", func(t *testing.T) {
		mock := config.NewMockPicker(t,
			config.PickerExpectation{Response: "fix"},
			config.PickerExpectation{Response: "Confirm"},
		)
		defer mock.AssertDone()
		buf := &bytes.Buffer{}

		cfg := CreateBranchNameConfigWithBase{
			BaseConfig: config.BaseConfig{
				Pick:   mock.AsPicker(),
				Print:  buf,
				AppDir: t.TempDir(),
			},
			CreateBranchNameConfig: CreateBranchNameConfig{
				PossiblePrefixes:    []string{"fix"},
				MaxBranchNameLength: 70,
			},
		}

		_, err := CreateBranchName(cfg, "UIEXT-1234", "Fix the koala bug", "Bug")
		if err != nil {
			t.Fatalf("CreateBranchName failed: %v", err)
		}

		if !strings.Contains(buf.String(), "New branch name: fix/UIEXT-1234-fix-the-koala-bug\n") {
			t.Errorf("expected print output to contain branch name, got %q", buf.String())
		}
	})

	t.Run("manual creation of branch slug", func(t *testing.T) {

		cases := []struct {
			name       string
			key        string
			prefix     string
			manualSlug string
			maxLen     int
			want       string
		}{
			{
				name:       "manual slug",
				key:        "UIEXT-1234",
				prefix:     "fix",
				manualSlug: "my-manual-slug",
				maxLen:     70,
				want:       "fix/UIEXT-1234-my-manual-slug",
			}, {
				name:       "truncates and cleans manual slug",
				key:        "UIEXT-1234",
				prefix:     "fix",
				manualSlug: "my non-slug manual slug!!! also too long",
				maxLen:     30,
				want:       "fix/UIEXT-1234-mynon-slugmanua",
			},
		}

		for _, tc := range cases {
			t.Run(tc.name, func(t *testing.T) {
				mock := config.NewMockPicker(t,
					config.PickerExpectation{Response: tc.prefix},
					config.PickerExpectation{Response: "Choose manually"},
					config.PickerExpectation{Response: tc.manualSlug},
				)
				defer mock.AssertDone()
				buf := &bytes.Buffer{}
				cfg := CreateBranchNameConfigWithBase{
					BaseConfig: config.BaseConfig{
						Pick:   mock.AsPicker(),
						Print:  buf,
						AppDir: t.TempDir(),
					},
					CreateBranchNameConfig: CreateBranchNameConfig{
						PossiblePrefixes:    []string{tc.prefix},
						MaxBranchNameLength: tc.maxLen,
					},
				}

				branchName, err := CreateBranchName(cfg, tc.key, "Fix the koala bug", "Bug")
				if err != nil {
					t.Fatalf("CreateBranchName failed: %v", err)
				}
				if branchName != tc.want {
					t.Errorf("got %q, want %q", branchName, tc.want)
				}
			})
		}
	})

	t.Run("additional branch name tools", func(t *testing.T) {
		t.Run("single tool succeeds", func(t *testing.T) {
			mock := config.NewMockPicker(t,
				config.PickerExpectation{Response: "fix"},
				config.PickerExpectation{Response: "Use tool (TestTool) to suggest another"},
				config.PickerExpectation{
					Prompt:   "Branch name: fix/UIEXT-1234-testtool-slug",
					Response: "Confirm",
				},
			)
			defer mock.AssertDone()
			buf := &bytes.Buffer{}

			cfg := CreateBranchNameConfigWithBase{
				BaseConfig: config.BaseConfig{
					Pick:   mock.AsPicker(),
					Print:  buf,
					AppDir: t.TempDir(),
				},
				CreateBranchNameConfig: CreateBranchNameConfig{
					PossiblePrefixes:    []string{"fix"},
					MaxBranchNameLength: 70,
					AdditionalBranchNameCreators: []BranchNameCreator{
						{
							Name: "TestTool",
							CreateName: func(name string, maxLength int) (string, error) {
								return "testtool-slug", nil
							},
						},
					},
				},
			}

			got, err := CreateBranchName(cfg, "UIEXT-1234", "Fix the koala bug", "Bug")
			if err != nil {
				t.Fatalf("CreateBranchName failed: %v", err)
			}
			if got != "fix/UIEXT-1234-testtool-slug" {
				t.Errorf("got %q, want %q", got, "fix/UIEXT-1234-testtool-slug")
			}
			if !strings.Contains(buf.String(), "TestTool came up with a suggestion\n") {
				t.Errorf("expected TestTool mentioned in output, got %q", buf.String())
			}
		})

		t.Run("two tools race and fastest wins", func(t *testing.T) {
			mock := config.NewMockPicker(t,
				config.PickerExpectation{Response: "fix"},
				config.PickerExpectation{Response: "Use tools (SlowTool, FastTool) to suggest another"},
				config.PickerExpectation{Response: "Confirm"},
			)
			defer mock.AssertDone()
			buf := &bytes.Buffer{}

			cfg := CreateBranchNameConfigWithBase{
				BaseConfig: config.BaseConfig{
					Pick:   mock.AsPicker(),
					Print:  buf,
					AppDir: t.TempDir(),
				},
				CreateBranchNameConfig: CreateBranchNameConfig{
					PossiblePrefixes:    []string{"fix"},
					MaxBranchNameLength: 70,
					AdditionalBranchNameCreators: []BranchNameCreator{
						{
							Name: "SlowTool",
							CreateName: func(name string, maxLength int) (string, error) {
								// Simulate slow by blocking on a channel that never sends
								select {}
							},
						},
						{
							Name: "FastTool",
							CreateName: func(name string, maxLength int) (string, error) {
								return "fast-slug", nil
							},
						},
					},
				},
			}

			got, err := CreateBranchName(cfg, "UIEXT-1234", "Fix the koala bug", "Bug")
			if err != nil {
				t.Fatalf("CreateBranchName failed: %v", err)
			}
			if got != "fix/UIEXT-1234-fast-slug" {
				t.Errorf("got %q, want %q", got, "fix/UIEXT-1234-fast-slug")
			}
			if !strings.Contains(buf.String(), "FastTool came up with a suggestion\n") {
				t.Errorf("expected FastTool to win, got %q", buf.String())
			}
		})

		t.Run("failing tool is skipped, second tool wins", func(t *testing.T) {
			// BadTool fails instantly, GoodTool waits briefly to ensure BadTool's error is processed first
			badDone := make(chan struct{})
			mock := config.NewMockPicker(t,
				config.PickerExpectation{Response: "fix"},
				config.PickerExpectation{Response: "Use tools (BadTool, GoodTool) to suggest another"},
				config.PickerExpectation{Response: "Confirm"},
			)
			defer mock.AssertDone()
			buf := &bytes.Buffer{}

			cfg := CreateBranchNameConfigWithBase{
				BaseConfig: config.BaseConfig{
					Pick:   mock.AsPicker(),
					Print:  buf,
					AppDir: t.TempDir(),
				},
				CreateBranchNameConfig: CreateBranchNameConfig{
					PossiblePrefixes:    []string{"fix"},
					MaxBranchNameLength: 70,
					AdditionalBranchNameCreators: []BranchNameCreator{
						{
							Name: "BadTool",
							CreateName: func(name string, maxLength int) (string, error) {
								defer close(badDone)
								return "", fmt.Errorf("model not available")
							},
						},
						{
							Name: "GoodTool",
							CreateName: func(name string, maxLength int) (string, error) {
								<-badDone // wait for BadTool to finish first
								return "good-slug", nil
							},
						},
					},
				},
			}

			got, err := CreateBranchName(cfg, "UIEXT-1234", "Fix the koala bug", "Bug")
			if err != nil {
				t.Fatalf("CreateBranchName failed: %v", err)
			}
			if got != "fix/UIEXT-1234-good-slug" {
				t.Errorf("got %q, want %q", got, "fix/UIEXT-1234-good-slug")
			}
			if !strings.Contains(buf.String(), "Error from BadTool") {
				t.Errorf("expected BadTool error logged, got %q", buf.String())
			}
			if !strings.Contains(buf.String(), "GoodTool came up with a suggestion\n") {
				t.Errorf("expected GoodTool to win, got %q", buf.String())
			}
		})
	})

}

package config

import (
	"fmt"
	"testing"
)

type PickerExpectation struct {
	Prompt   string
	Options  []string
	Response string
	Err      error
}

type MockPicker struct {
	t            *testing.T
	expectations []PickerExpectation
	callIndex    int
}

func NewMockPicker(t *testing.T, expectations ...PickerExpectation) *MockPicker {
	return &MockPicker{t: t, expectations: expectations}
}

func (m *MockPicker) Pick(prompt string, opts PickerOptions) (string, error) {
	if m.callIndex >= len(m.expectations) {
		m.t.Fatalf("unexpected Pick call #%d: prompt=%q", m.callIndex+1, prompt)
	}
	exp := m.expectations[m.callIndex]
	m.callIndex++

	if exp.Prompt != "" && prompt != exp.Prompt {
		m.t.Errorf("Pick call #%d: prompt = %q, want %q", m.callIndex, prompt, exp.Prompt)
	}
	if exp.Options != nil {
		if len(opts.Options) != len(exp.Options) {
			m.t.Errorf("Pick call #%d: got %d options, want %d", m.callIndex, len(opts.Options), len(exp.Options))
		} else {
			for i, opt := range opts.Options {
				if opt != exp.Options[i] {
					m.t.Errorf("Pick call #%d: option[%d] = %q, want %q", m.callIndex, i, opt, exp.Options[i])
				}
			}
		}
	}

	return exp.Response, exp.Err
}

func (m *MockPicker) AsPicker() Picker {
	return m.Pick
}

func (m *MockPicker) AssertDone() {
	if m.callIndex < len(m.expectations) {
		m.t.Errorf("expected %d Pick calls, got %d", len(m.expectations), m.callIndex)
	}
}

// Quick helper for tests that don't care about validating Pick args
func AlwaysPick(value string) Picker {
	return func(prompt string, opts PickerOptions) (string, error) {
		return value, nil
	}
}

func FailPick(msg string) Picker {
	return func(prompt string, opts PickerOptions) (string, error) {
		return "", fmt.Errorf("%s", msg)
	}
}

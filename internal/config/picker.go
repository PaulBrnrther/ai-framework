package config

type PickerCacheOptions struct {
	// Optional ID for two reasons:
	// If an inputValue is provided, the returned value can be remembered.
	// In any case, we can sort the options by MRU (most recently used).
	PickerID string
	// The directory under which MRU and association files are stored for this picker.
	RememberFilesDir string
	// An optional input value something should be picked for.
	// This way we can cache the picked value for the same input value (and same pickerID).
	InputValue string
}

type PickerOptions struct {
	// Possibly empty list of options. If empty, an arbitrary string should be returnable.
	Options []string
	// Optional value returned when the user presses tab instead of enter.
	// If empty, tab behaves normally (no special binding).
	TabOption string
	PickerCacheOptions
}

type Picker func(
	prompt string,
	options PickerOptions,
) (string, error)

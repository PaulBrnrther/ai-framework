package ticket

type Ticket struct {
	Key               string       `yaml:"key"` // TODO: Rename within existing yaml (previously "ticket")
	Name              string       `yaml:"name"`
	Type              string       `yaml:"type"`
	Description       string       `yaml:"description,omitempty"`
	DefaultBranchName string       `yaml:"default_branch_name,omitempty"`
	Repos             []RepoConfig `yaml:"repos,omitempty"`
}

type RepoConfig struct {
	Name          string         `yaml:"name"`
	Branches      []BranchConfig `yaml:"branches,omitempty"`
	CurrentBranch string         `yaml:"current_branch,omitempty"`
}

type BranchConfig struct {
	Name          string `yaml:"name"`
	BasedOn       string `yaml:"based_on,omitempty"`
	NotYetCreated bool   `yaml:"created,omitempty"`
	// Only used on creation
	UpstreamExists bool `yaml:"upstream_exists,omitempty"`
}

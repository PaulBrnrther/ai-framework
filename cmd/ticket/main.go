package main

import (
	"fmt"
	"os"

	"github.com/paulbaernreuther/ai-framework/internal/branch"
	"github.com/paulbaernreuther/ai-framework/internal/config"
	"github.com/paulbaernreuther/ai-framework/internal/ticket"
	"github.com/spf13/cobra"
)

var appDir = os.ExpandEnv("./tempCacheDuringDev")

var baseConfig = config.BaseConfig{
	Pick:   config.FzfPicker,
	Print:  os.Stdout,
	AppDir: appDir,
}

var rootCommand = &cobra.Command{
	Use:   "ticket",
	Short: "Manage ticket contexts",
}

var createCommand = &cobra.Command{
	Use:   "create <key> <name> <type>",
	Short: "Create a new ticket",
	Args:  cobra.ExactArgs(3),
	RunE: func(cmd *cobra.Command, args []string) error {
		key, name, ticketType := args[0], args[1], args[2]

		branchName, err := branch.CreateBranchName(branch.NewCreateBranchNameConfig(baseConfig, createBranchNameConfig), key, name, ticketType)
		if err != nil {
			return err
		}

		repos := []string{"knime-core-ui", "knime-base", "knime-database"} // TODO: discover from ~/knime/repos
		pickedRepo, err := baseConfig.Pick("Choose the first repository", config.PickerOptions{Options: repos})
		if err != nil {
			return err
		}

		t := ticket.Ticket{
			Key:               key,
			Name:              name,
			Type:              ticketType,
			DefaultBranchName: branchName,
			Repos:             []ticket.RepoConfig{{Name: pickedRepo}},
		}

		writeConfig := ticket.TicketWriteConfig{TicketsDir: appDir}
		if err := ticket.WriteTicket(writeConfig, t); err != nil {
			return err
		}

		fmt.Printf("Created ticket %s → %s\n", t.Key, t.DefaultBranchName)
		return nil
	},
}

func init() {
	rootCommand.AddCommand(createCommand)
}

func main() {
	if err := rootCommand.Execute(); err != nil {
		os.Exit(1)
	}
}

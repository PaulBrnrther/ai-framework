package ticket

import (
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

type TicketWriteConfig struct {
	TicketsDir string
}

func getFilePath(c TicketWriteConfig, key string) string {
	return filepath.Join(c.TicketsDir, key+".yaml")
}

func WriteTicket(c TicketWriteConfig, t Ticket) error {
	data, err := yaml.Marshal(t)
	if err != nil {
		return err
	}
	os.MkdirAll(c.TicketsDir, 0755)
	return os.WriteFile(getFilePath(c, t.Key), data, 0644)
}

func readTicket(c TicketWriteConfig, key string) (t Ticket, err error) {
	data, err := os.ReadFile(getFilePath(c, key))
	if err != nil {
		return
	}
	err = yaml.Unmarshal(data, &t)
	return

}

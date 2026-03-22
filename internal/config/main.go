package config

import (
	"io"
)

type BaseConfig struct {
	Pick   Picker
	Print  io.Writer
	AppDir string
}

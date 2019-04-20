package grifts

import (
	"github.com/cipepser/ril/actions"
	"github.com/gobuffalo/buffalo"
)

func init() {
	buffalo.Grifts(actions.App())
}

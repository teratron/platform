package conf

import (
	"os"
)

const (
	SITE_NAME   string = "LocTalk"
	DEFAULT_LIMIT  int = 10
	MAX_LIMIT      int = 1000
	MAX_POST_CHARS int = 1000
)

func init() {
	mode := os.Getenv("MARTINI_ENV")

	switch mode {
		case "production":
			SiteUrl = "http://loctalk.net"
			AbsolutePath = "d:/projects/platform/"
		default:
			SiteUrl = "http://127.0.0.1"
			AbsolutePath = "d:/projects/platform/"
	}
}
package main

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	"github.com/zabisa/platform/packages/go/platform/auth"
)

func main() {
	password, err := bufio.NewReader(os.Stdin).ReadString('\n')
	if err != nil && len(password) == 0 {
		fmt.Fprintln(os.Stderr, "password input is required")
		os.Exit(1)
	}

	password = strings.TrimSuffix(strings.TrimSuffix(password, "\n"), "\r")
	hash, err := auth.HashPassword(password)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}

	fmt.Println(hash)
}

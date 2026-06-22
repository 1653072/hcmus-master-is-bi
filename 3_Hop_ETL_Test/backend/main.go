package main

// Run from this directory: go run .
import "log"

func main() {
	if err := RunPushMDMUserDemo(); err != nil {
		log.Fatal(err)
	}
}

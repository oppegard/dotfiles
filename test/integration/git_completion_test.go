package integration

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"os/exec"
	"regexp"
	"strings"
	"sync"
	"time"
)

type terminalTranscript struct {
	mu     sync.Mutex
	buffer bytes.Buffer
}

func (transcript *terminalTranscript) Write(data []byte) (int, error) {
	transcript.mu.Lock()
	defer transcript.mu.Unlock()
	return transcript.buffer.Write(data)
}

func (transcript *terminalTranscript) snapshot() string {
	transcript.mu.Lock()
	defer transcript.mu.Unlock()
	return transcript.buffer.String()
}

func checkGitCompletion(parent context.Context, dir string, env []string) (err error) {
	ctx, cancel := context.WithTimeout(parent, 30*time.Second)
	defer cancel()
	var transcript terminalTranscript
	defer func() {
		if err != nil {
			err = fmt.Errorf("%w\nterminal transcript:\n%s", err, transcript.snapshot())
		}
	}()

	cmd := exec.CommandContext(ctx, "/usr/bin/script", "-q", "/dev/null", "/opt/homebrew/bin/bash", "-li")
	cmd.Dir = dir
	cmd.Env = append(append([]string(nil), env...), "TERM=dumb", "HISTFILE=/dev/null")
	cmd.Stdout = &transcript
	cmd.Stderr = &transcript
	cmd.WaitDelay = time.Second
	input, err := cmd.StdinPipe()
	if err != nil {
		return err
	}
	defer input.Close()
	if err := cmd.Start(); err != nil {
		return err
	}
	exited := make(chan error, 1)
	go func() { exited <- cmd.Wait() }()
	defer func() {
		cancel()
		if exited != nil {
			<-exited
		}
	}()

	if _, err := io.WriteString(input, "printf '\\nDOTFILES_\\122EADY\\n'\n"); err != nil {
		return err
	}
	const ready = "\r\nDOTFILES_READY\r\n"
	checkout := regexp.MustCompile(`\bcheckout\b`)
	cherryPick := regexp.MustCompile(`\bcherry-pick\b`)
	phase := "startup"
	completionStart := 0
	ticker := time.NewTicker(10 * time.Millisecond)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return fmt.Errorf("Git Tab completion timed out during %s: %w", phase, ctx.Err())
		case err := <-exited:
			exited = nil
			if err != nil {
				return fmt.Errorf("interactive Bash failed during %s: %w", phase, err)
			}
			if phase != "exit" {
				return fmt.Errorf("interactive Bash exited before Git Tab completion during %s", phase)
			}
			return nil
		case <-ticker.C:
			output := transcript.snapshot()
			switch phase {
			case "startup":
				if offset := strings.Index(output, ready); offset >= 0 {
					completionStart = offset + len(ready)
					if _, err := io.WriteString(input, "git che\t"); err != nil {
						return err
					}
					phase = "completion"
				}
			case "completion":
				candidates := output[completionStart:]
				if checkout.MatchString(candidates) && cherryPick.MatchString(candidates) {
					if _, err := io.WriteString(input, "\x15exit\n"); err != nil {
						return err
					}
					phase = "exit"
				}
			}
		}
	}
}

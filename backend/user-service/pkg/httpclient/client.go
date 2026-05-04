package httpclient

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

type Client struct {
	base       string
	http       *http.Client
	maxRetries int
}

func New(base string, timeout time.Duration, retries int) *Client {
	return &Client{base: base, http: &http.Client{Timeout: timeout}, maxRetries: retries}
}

func (c *Client) Post(ctx context.Context, path string, body interface{}, reqID string) error {
	b, err := json.Marshal(body)
	if err != nil { return err }
	var last error
	for i := 0; i <= c.maxRetries; i++ {
		if i > 0 { time.Sleep(time.Duration(i*200) * time.Millisecond) }
		req, _ := http.NewRequestWithContext(ctx, "POST", c.base+path, bytes.NewReader(b))
		req.Header.Set("Content-Type", "application/json")
		if reqID != "" { req.Header.Set("X-Request-ID", reqID) }
		resp, err := c.http.Do(req)
		if err != nil { last = err; continue }
		resp.Body.Close()
		if resp.StatusCode >= 200 && resp.StatusCode < 300 { return nil }
		if resp.StatusCode >= 400 && resp.StatusCode < 500 { return fmt.Errorf("client error: %d", resp.StatusCode) }
		last = fmt.Errorf("server error: %d", resp.StatusCode)
	}
	return fmt.Errorf("all retries failed: %w", last)
}

package ai

import "testing"

// Танҳо OPENAI_API_KEY: калиди OpenAI набояд ба Groq фиристода шавад.
func TestConfigForOpenAIOnly(t *testing.T) {
	for _, k := range []string{"AI_CHAT_API_KEY", "AI_API_KEY", "TUTOR_API_KEY",
		"AI_CHAT_API_URL", "AI_API_URL", "TUTOR_API_URL", "AI_CHAT_MODEL", "AI_MODEL", "OPENAI_MODEL"} {
		t.Setenv(k, "")
	}
	t.Setenv("OPENAI_API_KEY", "sk-test")
	c := ConfigFor(TaskChat)
	if c.APIURL != "https://api.openai.com/v1/chat/completions" || c.Model != "gpt-4o-mini" {
		t.Fatalf("OpenAI key routed to %s / %s", c.APIURL, c.Model)
	}
	t.Setenv("AI_API_KEY", "gsk-test")
	c = ConfigFor(TaskChat)
	if c.APIKey != "gsk-test" || c.APIURL != defaultURL {
		t.Fatalf("AI_API_KEY must win and use default provider: %+v", c)
	}
}

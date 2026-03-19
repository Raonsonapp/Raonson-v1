package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
)

type User struct {
	Username string `json:"username"`
	Email    string `json:"email"`
	Password string `json:"password"`
}

func main() {

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(map[string]string{
			"status": "ok",
		})
	})

	http.HandleFunc("/register", register)

	fmt.Println("Server running on port", port)
	http.ListenAndServe(":"+port, nil)
}

func register(w http.ResponseWriter, r *http.Request) {

	if r.Method != http.MethodPost {
		http.Error(w, "POST only", 405)
		return
	}

	var user User

	err := json.NewDecoder(r.Body).Decode(&user)
	if err != nil {
		http.Error(w, "Invalid JSON", 400)
		return
	}

	// simple validation
	if user.Email == "" || user.Password == "" {
		http.Error(w, "Missing fields", 400)
		return
	}

	json.NewEncoder(w).Encode(map[string]string{
		"message":  "User registered ✅",
		"username": user.Username,
	})
}

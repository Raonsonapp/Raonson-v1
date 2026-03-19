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

var fakeUser User

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
	http.HandleFunc("/login", login)

	fmt.Println("Server running on port", port)
	http.ListenAndServe(":"+port, nil)
}

func register(w http.ResponseWriter, r *http.Request) {

	if r.Method != http.MethodPost {
		http.Error(w, "POST only", 405)
		return
	}

	var user User
	json.NewDecoder(r.Body).Decode(&user)

	if user.Email == "" || user.Password == "" {
		http.Error(w, "Missing fields", 400)
		return
	}

	// save in memory (temporary)
	fakeUser = user

	json.NewEncoder(w).Encode(map[string]string{
		"message": "Registered ✅",
	})
}

func login(w http.ResponseWriter, r *http.Request) {

	if r.Method != http.MethodPost {
		http.Error(w, "POST only", 405)
		return
	}

	var user User
	json.NewDecoder(r.Body).Decode(&user)

	if user.Email == fakeUser.Email && user.Password == fakeUser.Password {
		json.NewEncoder(w).Encode(map[string]string{
			"token": "raonson-token-123",
		})
		return
	}

	http.Error(w, "Invalid login", 401)
}

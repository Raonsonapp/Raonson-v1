package main

import (
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"os"

	_ "github.com/lib/pq"
)

var db *sql.DB

func main() {
	var err error
	db, err = sql.Open("postgres", os.Getenv("DATABASE_URL"))
	if err != nil {
		log.Fatal(err)
	}

	http.HandleFunc("/", home)
	http.HandleFunc("/register", register)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Println("Server running on port", port)
	http.ListenAndServe(":"+port, nil)
}

func home(w http.ResponseWriter, r *http.Request) {
	json.NewEncoder(w).Encode(map[string]string{
		"status": "ok",
	})
}

func register(w http.ResponseWriter, r *http.Request) {
	var user struct {
		Username string `json:"username"`
		Email    string `json:"email"`
		Password string `json:"password"`
	}

	json.NewDecoder(r.Body).Decode(&user)

	_, err := db.Exec(
		"INSERT INTO users (username, email, password) VALUES ($1, $2, $3)",
		user.Username, user.Email, user.Password,
	)

	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}

	json.NewEncoder(w).Encode(map[string]string{
		"message": "User created",
	})
}

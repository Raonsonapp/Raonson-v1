package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"os"

	_ "github.com/lib/pq"
)

var db *sql.DB

type User struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

func main() {
	var err error

	db, err = sql.Open("postgres", os.Getenv("DATABASE_URL"))
	if err != nil {
		panic(err)
	}

	err = db.Ping()
	if err != nil {
		panic(err)
	}

	fmt.Println("Database connected ✅")

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	http.HandleFunc("/register", register)
	http.HandleFunc("/login", login)

	fmt.Println("Server running on port", port)
	http.ListenAndServe(":"+port, nil)
}

func register(w http.ResponseWriter, r *http.Request) {
	var u User
	json.NewDecoder(r.Body).Decode(&u)

	_, err := db.Exec(
		"INSERT INTO users (email, password) VALUES ($1,$2)",
		u.Email, u.Password,
	)

	if err != nil {
		http.Error(w, "DB error", 500)
		return
	}

	json.NewEncoder(w).Encode(map[string]string{
		"message": "ok",
	})
}

func login(w http.ResponseWriter, r *http.Request) {
	var u User
	json.NewDecoder(r.Body).Decode(&u)

	var pass string

	err := db.QueryRow(
		"SELECT password FROM users WHERE email=$1",
		u.Email,
	).Scan(&pass)

	if err != nil {
		http.Error(w, "not found", 404)
		return
	}

	if pass != u.Password {
		http.Error(w, "wrong", 401)
		return
	}

	json.NewEncoder(w).Encode(map[string]string{
		"token": "ok",
	})
}

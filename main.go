package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"

	"github.com/jackc/pgx/v5"
)

var conn *pgx.Conn

type User struct {
	Username string `json:"username"`
	Email    string `json:"email"`
	Password string `json:"password"`
}

func main() {
	var err error

	conn, err = pgx.Connect(context.Background(), os.Getenv("DATABASE_URL"))
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
	var user User
	json.NewDecoder(r.Body).Decode(&user)

	_, err := conn.Exec(context.Background(),
		"INSERT INTO users (username, email, password) VALUES ($1, $2, $3)",
		user.Username, user.Email, user.Password,
	)

	if err != nil {
		http.Error(w, "DB error", 500)
		return
	}

	json.NewEncoder(w).Encode(map[string]string{
		"message": "Saved in DB ✅",
	})
}

func login(w http.ResponseWriter, r *http.Request) {
	var user User
	json.NewDecoder(r.Body).Decode(&user)

	var dbPassword string

	err := conn.QueryRow(context.Background(),
		"SELECT password FROM users WHERE email=$1",
		user.Email,
	).Scan(&dbPassword)

	if err != nil {
		http.Error(w, "User not found", 404)
		return
	}

	if dbPassword != user.Password {
		http.Error(w, "Invalid login", 401)
		return
	}

	json.NewEncoder(w).Encode(map[string]string{
		"token": "real-token-123",
	})
}

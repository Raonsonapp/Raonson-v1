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

	// пайвастшавӣ ба PostgreSQL (Supabase)
	db, err = sql.Open("postgres", os.Getenv("DATABASE_URL"))
	if err != nil {
		log.Fatal("Database error:", err)
	}

	err = db.Ping()
	if err != nil {
		log.Fatal("Cannot connect DB:", err)
	}

	log.Println("Connected to database ✅")

	// routes
	http.HandleFunc("/", home)
	http.HandleFunc("/register", register)

	// порт
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Println("Server running on port", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

// 🟢 Home route
func home(w http.ResponseWriter, r *http.Request) {
	json.NewEncoder(w).Encode(map[string]string{
		"status":  "ok",
		"message": "Raonson Go Backend 🚀",
	})
}

// 🟢 Register route
func register(w http.ResponseWriter, r *http.Request) {

	// 👉 агар аз браузер (GET) биёяд
	if r.Method == "GET" {
		_, err := db.Exec(
			"INSERT INTO users (username, email, password) VALUES ($1, $2, $3)",
			"testuser", "test@gmail.com", "123456",
		)

		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}

		w.Write([]byte("User created from browser ✅"))
		return
	}

	// 👉 агар POST бошад (API)
	var user struct {
		Username string `json:"username"`
		Email    string `json:"email"`
		Password string `json:"password"`
	}

	err := json.NewDecoder(r.Body).Decode(&user)
	if err != nil {
		http.Error(w, "Invalid JSON", 400)
		return
	}

	_, err = db.Exec(
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

package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
)

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

	http.HandleFunc("/register", func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(map[string]string{
			"message": "Register working ✅",
		})
	})

	fmt.Println("Server running on port", port)
	http.ListenAndServe(":"+port, nil)
}

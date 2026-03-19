package main

import (
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
		fmt.Fprintln(w, "Backend working without DB ✅")
	})

	fmt.Println("Server running on port", port)
	http.ListenAndServe(":"+port, nil)
}

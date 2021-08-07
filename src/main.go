package main

import (
	"csgoMatchPlattform/src/serverHandler"
	"csgoMatchPlattform/src/utils"
	"csgoMatchPlattform/src/workshoputils"
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/joho/godotenv"
)

const HTTP_PORT = 8080

// HTTP Server Handler for /create URL
func createHandler(w http.ResponseWriter, r *http.Request, maps []workshoputils.Map) {
	// Start server
	// Get not in use Game Server Login Token
	gslt, err := serverHandler.GetGSLT()
	if err != nil {
		fmt.Fprintf(w, "{\"Status\": \"error\", \"Error\": \"%s\"}", err.Error())
	} else {
		// Get not in use Port
		port, err := serverHandler.GetPort()
		if err != nil {
			fmt.Fprintf(w, "{\"Status\": \"error\", \"Error\": \"%s\"}", err.Error())
		} else {
			portInt, _ := strconv.Atoi(port)
			mapInput, ok := r.URL.Query()["id"]
			var mapId string
			if !ok || len(mapInput[0]) < 1 {
				// Generate random mapId if no id parameter
				rand.Seed(time.Now().UnixNano())
				mapId = maps[rand.Intn(len(maps))].Id
			} else {
				mapId = mapInput[0]
			}
			data := serverHandler.Server{Name: utils.GenerateName(), GSLT: gslt, Port: portInt, Channel: make(chan string), Map: mapId}
			serverHandler.AddServer(data)
			val, ok := <-data.Channel
			if ok {
				ip, err := utils.GetIP()
				if err != nil {
					w.WriteHeader(500)
					fmt.Fprintf(w, "{\"Status\": \"error\", \"Error\": \"%s\"}", err)
				} else {
					var URL = "steam://connect/" + ip + ":" + strconv.Itoa(data.Port)
					resp := serverHandler.ServerStatus{Name: data.Name, MapId: data.Map, Port: data.Port, Status: val, IP: ip, URL: URL}
					w.Header().Set("Content-Type", "application/json")
					w.WriteHeader(http.StatusCreated)
					json.NewEncoder(w).Encode(resp)
				}
			} else {
				fmt.Fprint(w, "{\"Status\": \"error\", \"Error\": \"Channel closed!\"}")
			}
		}
	}
}

// Program starts here:
func main() {
	// Load .env file
	err := godotenv.Load()
	if err != nil {
		log.Print("Warning could not load .env file!")
	}

	// Set environement variables
	serverHandler.GSLTS = strings.Split(os.Getenv("GSLTS"), ",")
	serverHandler.InstallDir = os.Getenv("HOME") + "/csgo-base/"
	serverHandler.AuthKey = os.Getenv("AUTHKEY")
	serverHandler.WS_Collection = os.Getenv("WS_COLLECTION")
	serverHandler.PortStart = os.Getenv("PORTSTART")
	
	// Delete all files of active sessions before
	utils.CleanUp(serverHandler.InstallDir + "../")

	// Get maplist
	maps, err := workshoputils.GetMaps(serverHandler.WS_Collection)
	for err != nil {
		maps, err = workshoputils.GetMaps(serverHandler.WS_Collection)
		fmt.Print(err)
	}

	// Set HTTP Handlers
	http.HandleFunc("/create", func(w http.ResponseWriter, r *http.Request) {
		createHandler(w, r, maps)
	})
	// HTTP Server Handler for /maps URL
	http.HandleFunc("/maps", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(maps)
	})

	// Start HTTP Server
	err = http.ListenAndServe(":"+strconv.FormatInt(HTTP_PORT, 10), nil)
	if err != nil {
		log.Fatalf("Could not start Webserver, error: %s", err)
	}
	log.Printf("HTTP Server started on Port: %s", strconv.FormatInt(HTTP_PORT, 10))
}

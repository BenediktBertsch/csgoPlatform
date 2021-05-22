package utils

import (
	"encoding/json"
	"io/ioutil"
	"log"
	"math/rand"
	"net/http"
	"os"
	"strings"
	"time"
)

var ServerList []string

const possible = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
const nameLength = 6
const IpAPI = "https://api.ipify.org?format=json"

// Returns an unique servername
func GenerateName() string {
	val := ""
	// Seed source is Nanoseconds of the system for pseudo generated characters
	rand.Seed(time.Now().UnixNano())
	for {
		for i := 0; i < nameLength; i++ {
			// Generates random number between 0 -> Len(possible)
			rand := rand.Intn(len(possible))

			// Generated number is the index of the new character
			// which gets added to the string
			val += string(possible[rand])
		}

		// Check if servername already exist
		var check bool
		for i := 0; i < len(ServerList); i++ {
			if ServerList[i] == val {
				check = true
			}
		}

		// If no entry of serverlist is the same as the new generated name
		// return it, otherwise loop again until it is unique
		if !check {
			break
		}
	}
	return "csgo@" + val
}

// Returns an unique password
func GeneratePassword() string {
	val := ""
	rand.Seed(time.Now().UnixNano())
	for i := 0; i < nameLength; i++ {
		rand := rand.Intn(len(possible))
		val += string(possible[rand])
	}
	return val
}

// Cleanup reads all files of a directory and
// deletes all that are still from the last run of the program
func CleanUp(path string) {
	entries, err := ioutil.ReadDir(path)
	if err != nil {
		log.Panicf("Failed reading directory: %s", err)
	}
	for _, v := range entries {
		if strings.Contains(v.Name(), "@") {
			if v.IsDir() {
				err := os.RemoveAll(path + v.Name())
				if err != nil {
					log.Println(err.Error())
				}
			} else {
				err := os.Remove(path + v.Name())
				if err != nil {
					log.Println(err.Error())
				}
			}
			// log.Printf("Deleted file/dir: %s", v.Name())
		}
	}
}

func GetIP() (string, error) {
	address := address{}
	resp, err := http.Get(IpAPI)
	if err != nil {
		return "", err
	}
	decoder := json.NewDecoder(resp.Body)
	defer resp.Body.Close()
	err = decoder.Decode(&address)
	if err != nil {
		return "", err
	}
	return address.IP, err
}

type address struct {
	IP string `json:"ip"`
}

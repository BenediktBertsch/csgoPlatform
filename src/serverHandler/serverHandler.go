package serverHandler

import (
	"bufio"
	"errors"
	"io/fs"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"strconv"
	"strings"
)

var GSLTS []string
var inUseGSLTS []string
var Ports = []string{"27015", "27016", "27017", "27018", "27019"}
var inUsePorts []string
var AuthKey string
var InstallDir string
var WS_Collection string
var PortStart string

// Entrypoint to add server
func AddServer(data Server) {
	go collect(data)
	go start(data)
}

func freeToUseCheck(arrayToCheck []string, arrayToCheckTwo []string) (string, error) {
	for i := 0; i < len(arrayToCheck); i++ {
		var check bool
		for v := 0; v < len(arrayToCheckTwo); v++ {
			if arrayToCheck[i] == arrayToCheckTwo[v] {
				check = true
			}
		}
		if !check {
			return arrayToCheck[i], nil
		}
	}
	return "", errors.New("no free to use keys / ports available at the moment")
}

func GetPort() (string, error) {
	s, err := freeToUseCheck(Ports, inUsePorts)
	inUsePorts = append(inUsePorts, s)
	return s, err
}

func GetGSLT() (string, error) {
	s, err := freeToUseCheck(GSLTS, inUseGSLTS)
	inUseGSLTS = append(inUseGSLTS, s)
	return s, err
}

func collect(data Server) {
	ready := false
	for {
		msg := <-data.Channel
		if !ready && msg == "ready" {
			log.Printf("Status %s: %s\n", data.Name, msg)
			ready = true
		} else if msg == "error" {
			log.Printf("Status %s: %s\n", data.Name, msg + ", check your servertokens for expiration dates: https://steamcommunity.com/dev/managegameservers")
			ready = false
		} else if msg == "stopped" {
			log.Printf("Status %s: %s\n", data.Name, msg)
			ready = false
		}
	}
}

// Create folder and symbolic links to csgo-base + sets password
func createServer(name string) {
	err := os.Mkdir(InstallDir+"/../"+name, os.ModePerm)
	if err != nil {
		log.Panicf("Failed creating directory: %s", err)
	}
	files, err := ioutil.ReadDir(InstallDir)
	if err != nil {
		log.Panicf("Failed reading directory: %s", err)
	}
	for _, v := range files {
		oldname := strings.Join([]string{InstallDir, v.Name()}, "")
		err = os.Symlink(oldname, strings.Replace(oldname, "csgo-base", name, -1))
		if err != nil {
			log.Panicf("Failed creating symlink: %s", err)
		}
	}
}

func start(data Server) {
	// Create game files
	createServer(data.Name)

	// Configure the start command
	cmd := exec.Command("unbuffer", "/home/admin/"+data.Name+"/srcds_run", "-game", "csgo", "-usercon", "+exec", "server.cfg", "-tickrate", "128", "-port", strconv.FormatInt(int64(data.Port), 10), "+sv_setsteamaccount", data.GSLT, "+host_workshop_collection", WS_Collection, "+workshop_start_map", data.Map, "-authkey", AuthKey, "-maxplayers_override", "2", "-nobots")
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		log.Println(err)
	}

	// Starting server
	err = cmd.Start()
	if err != nil {
		data.Channel <- "Could not start:" + err.Error()
	} else {
		// Read stream (srcds console)
		buf := bufio.NewReader(stdout)
		f, err := os.OpenFile("/home/admin/"+data.Name+".log", os.O_APPEND|os.O_CREATE|os.O_WRONLY, fs.ModePerm)
		if err != nil {
			log.Println(err)
		}
		defer f.Close()
		for {
			line, _, _ := buf.ReadLine()

			// Write to log
			_, err := f.WriteString(string(line) + "\n")
			if err != nil {
				log.Println(err)
			}

			// Check if server is up
			if strings.Contains(string(line), "Error parsing BotProfile.db - unknown attribute 'Rank'") {
				data.Channel <- "ready"
			}

			// Check if server is up
			if strings.Contains(string(line), "FATAL ERROR") {
				data.Channel <- "error"
			}

			
			// Check if server is down
			if strings.Contains(string(line), "Server Quit") {
				data.Channel <- "stopped"
				removeServer(data)
				break
			}
		}
	}
}

func removeServer(data Server) {
	// Delete folder
	entries, err := ioutil.ReadDir(InstallDir + "../")
	if err != nil {
		log.Panicf("Failed reading directory: %s", err)
	}
	for _, v := range entries {
		if strings.Contains(v.Name(), data.Name) {
			if v.IsDir() {
				err := os.RemoveAll(InstallDir + "../" + v.Name())
				if err != nil {
					log.Println(err.Error())
				}
			} else {
				err := os.Remove(InstallDir + "../" + v.Name())
				if err != nil {
					log.Println(err.Error())
				}
			}
		}
	}

	// Remove GSLT Key and Port (inuse)
	deleteInUse(true, data.GSLT)
	deleteInUse(false, data.Port)
}

func deleteInUse(typ bool, value interface{}) {
	// type true -> GSLT else Port
	index := 0
	if typ {
		for _, i := range inUseGSLTS {
			if i == value {
				inUseGSLTS[index] = i
				index++
			}
		}
		inUseGSLTS = inUseGSLTS[:index]
	} else {
		for _, i := range inUsePorts {
			if i == value {
				inUsePorts[index] = i
				index++
			}
		}
		inUsePorts = inUsePorts[:index]
	}
}

type Server struct {
	Name    string
	GSLT    string
	Port    int
	Map     string
	Channel chan string
}

type ServerStatus struct {
	Name   string
	MapId  string
	IP     string
	Port   int
	Status string
	URL    string
}

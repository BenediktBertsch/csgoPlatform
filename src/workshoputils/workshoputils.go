package workshoputils

import (
	"bytes"
	"encoding/json"
	"io/ioutil"
	"mime/multipart"
	"net/http"
	"strconv"
)

const collectionAddress = "https://api.steampowered.com/ISteamRemoteStorage/GetCollectionDetails/v1/?format=jsn"
const itemAddress = "https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/?format=json"

func GetMaps(WS_Collection string) ([]Map, error) {
	payload := &bytes.Buffer{}
	writer := multipart.NewWriter(payload)
	_ = writer.WriteField("collectioncount", "1")
	_ = writer.WriteField("publishedfileids[0]", WS_Collection)
	err := writer.Close()
	if err != nil {
		return nil, err
	}
	client := &http.Client {}
	req, err := http.NewRequest("POST", collectionAddress, payload)
	
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", writer.FormDataContentType())
	res, err := client.Do(req)
	if err != nil {
	 return nil, err
	}
	defer res.Body.Close()
	body, err := ioutil.ReadAll(res.Body)
	if err != nil {
		return nil, err
	}
	
	// JSON to Struct
	var collection Collection
	if err := json.Unmarshal(body, &collection); err != nil {
		return nil, err
	}

	// Store all publishedfileid
	payload = &bytes.Buffer{}
	writer = multipart.NewWriter(payload)
	_= writer.WriteField("itemcount", strconv.Itoa(len(collection.Response.Collectiondetails[0].Children)))
	for i, item :=range collection.Response.Collectiondetails[0].Children {
	_ = writer.WriteField("publishedfileids["+strconv.Itoa(i)+"]", item.Publishedfileid)
	}
	writer.Close()

	// Get informaton of all publishedfileids
	req, err = http.NewRequest("POST", itemAddress, payload)
	req.Header.Set("Content-Type", writer.FormDataContentType())
	if err != nil {
		return nil, err
	}
	res, err = client.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()
	body, err = ioutil.ReadAll(res.Body)
	if err != nil {
		return nil, err
	}
	
	// Decode Respone
	var items Items
	if err := json.Unmarshal(body, &items); err != nil {
		return nil, err
	}

	// Get needed information
	var maps []Map
	for _, item := range items.Response.Publishedfiledetails {
		maps = append(maps, Map{Name: item.Title, PicLink: item.PreviewURL, Id: item.Publishedfileid})
	}
	return maps, nil
}

type Map struct {
	Name    string
	PicLink string
	Id		string
}

// Item
type Items struct {
	Response struct {
		Result               int `json:"result"`
		Resultcount          int `json:"resultcount"`
		Publishedfiledetails []struct {
			Publishedfileid       string `json:"publishedfileid"`
			Result                int    `json:"result"`
			Creator               string `json:"creator,omitempty"`
			CreatorAppID          int    `json:"creator_app_id,omitempty"`
			ConsumerAppID         int    `json:"consumer_app_id,omitempty"`
			Filename              string `json:"filename,omitempty"`
			FileSize              int    `json:"file_size,omitempty"`
			FileURL               string `json:"file_url,omitempty"`
			HcontentFile          string `json:"hcontent_file,omitempty"`
			PreviewURL            string `json:"preview_url,omitempty"`
			HcontentPreview       string `json:"hcontent_preview,omitempty"`
			Title                 string `json:"title,omitempty"`
			Description           string `json:"description,omitempty"`
			TimeCreated           int    `json:"time_created,omitempty"`
			TimeUpdated           int    `json:"time_updated,omitempty"`
			Visibility            int    `json:"visibility,omitempty"`
			Banned                int    `json:"banned,omitempty"`
			BanReason             string `json:"ban_reason,omitempty"`
			Subscriptions         int    `json:"subscriptions,omitempty"`
			Favorited             int    `json:"favorited,omitempty"`
			LifetimeSubscriptions int    `json:"lifetime_subscriptions,omitempty"`
			LifetimeFavorited     int    `json:"lifetime_favorited,omitempty"`
			Views                 int    `json:"views,omitempty"`
			Tags                  []struct {
				Tag string `json:"tag"`
			} `json:"tags,omitempty"`
		} `json:"publishedfiledetails"`
	} `json:"response"`
}

// Collection
type Collection struct{
	Response Response `json:"response"`
}
type Children struct {
	Publishedfileid string `json:"publishedfileid"`
	Sortorder       int    `json:"ortorder"`
	Filetype        int    `json:"filetype"`
}
type Collectiondetails struct {
	Publishedfileid string     `json:"publishedfileid"`
	Result          int       `json:"result"`
	Children        []Children `json:"children"`
}
type Response struct {
	Result            int                 `json:"result"`
	Resultcount       int                 `json:"resultcount"`
	Collectiondetails []Collectiondetails `json:"collectiondetails"`
}

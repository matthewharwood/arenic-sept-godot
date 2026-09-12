class_name ArenicHeroNames
extends RefCounted
## Deterministic display names for future generated heroes; this creates no actors.

const NAME_COUNT: int = 100
const NAME_COMBINATIONS: int = 10000
const FIRST_NAMES: PackedStringArray = [
	"Arlen", "Asha", "Alden", "Alina", "Ansel", "Anya", "Aric", "Astrid", "Avery", "Azra",
	"Bastian", "Beatrix", "Bennett", "Briar", "Bryn", "Cadence", "Callan", "Cassia", "Cedric", "Celia",
	"Cian", "Clara", "Corin", "Dahlia", "Darian", "Delia", "Dorian", "Eira", "Elian", "Elise",
	"Ember", "Emrys", "Enid", "Evander", "Faye", "Felix", "Fenric", "Fiona", "Flora", "Galen",
	"Gemma", "Gideon", "Greta", "Hadrian", "Hana", "Hazel", "Hugo", "Idris", "Ilya", "Ines",
	"Iona", "Iris", "Isolde", "Jasper", "Jessa", "Jonas", "Juno", "Kael", "Kara", "Kieran",
	"Lara", "Leif", "Lenora", "Liora", "Lucan", "Lyra", "Maeve", "Magnus", "Mara", "Milo",
	"Mira", "Nadia", "Nessa", "Nico", "Nolan", "Nora", "Oren", "Orla", "Oscar", "Petra",
	"Quinn", "Rafe", "Rhea", "Ronan", "Rosalind", "Rowan", "Sabine", "Sable", "Sera", "Silas",
	"Soren", "Talia", "Tamsin", "Theo", "Tobin", "Una", "Vera", "Wren", "Yara", "Zev",
]
const LAST_NAMES: PackedStringArray = [
	"Ashford", "Amberfall", "Alderbrook", "Arden", "Ashvale", "Bellweather", "Blackthorn", "Brightwater", "Briarwood", "Brookstone",
	"Cinderhall", "Clearwell", "Cloudmere", "Copperfield", "Crowhurst", "Dawnbrook", "Deepwell", "Duskwood", "Duskmere", "Dunvale",
	"Eastwind", "Elderwood", "Emberfall", "Everhart", "Evenwood", "Fairbrook", "Faraday", "Fernwood", "Flintlock", "Foxglove",
	"Goldcrest", "Goodwin", "Graystone", "Greenbriar", "Groveward", "Halloway", "Hartwell", "Hawthorne", "Highwater", "Hollowbrook",
	"Ironbloom", "Ironcrest", "Iverstone", "Ivydale", "Ivoryvale", "Jadebrook", "Juniper", "Kingswell", "Kestrel", "Kindlewood",
	"Larkspur", "Lightfoot", "Longmere", "Lowell", "Lynden", "Meadowvale", "Merriwether", "Moonbrook", "Mossgrove", "Mistborne",
	"Nettleford", "Nightbloom", "Northwind", "Norwood", "Oakheart", "Oakley", "Oakhurst", "Oriel", "Pinebrook", "Pryce",
	"Quill", "Quarryborn", "Ravencrest", "Redfern", "Ridgewell", "Riverstone", "Rosewood", "Rowntree", "Silverleaf", "Snowden",
	"Springvale", "Starling", "Stoneward", "Summerfield", "Thistlewood", "Thornfield", "Timberfall", "Tidewell", "Underhill", "Umberfield",
	"Vale", "Verdant", "Westfall", "Whitethorn", "Wildmere", "Willowby", "Winterborne", "Woodward", "Yarrow", "Zephyr",
]


## Every pair appears once per 10,000 identities. Consecutive IDs have varied
## surnames; IDs, rather than the repeating display names, remain authoritative.
## Normalize first so even a signed 64-bit boundary cannot overflow the pairing.
static func name_for_id(identity_id: int) -> String:
	var normalized := posmod(identity_id, NAME_COMBINATIONS)
	var first := normalized % NAME_COUNT
	@warning_ignore("integer_division")
	var last := (normalized / NAME_COUNT + first * 37) % NAME_COUNT
	return FIRST_NAMES[first] + " " + LAST_NAMES[last]

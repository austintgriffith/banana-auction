let fs = require('fs');
let path = require('path');

// let rawData = fs.readFileSync(path.join(__dirname, './collection-metadata/metadata-69.json'));
// let d = JSON.parse(rawData);

let base = {"name":"Banana #69","description":"Illustrations by Chris Kag. Contract by nnnnicholas, Austin Griffith, and Viraz Malhotra with help from 0xBa5ed and DrGorilla.","image":"ipfs://QmTeamx7zoU1uRDEwbSZnbiETrqKrHa3Y4jWk6P6xaSUen/69"};

mut(base)

function mut(obj) {
    let i;
    for (i = 1; i < 70; i++) {
        obj.name = "Banana #" + i;
        obj.image = "ipfs://QmTeamx7zoU1uRDEwbSZnbiETrqKrHa3Y4jWk6P6xaSUen/" + i + ".png";
        fs.writeFileSync(path.join(__dirname, './collection-metadata/for-upload/' + i), JSON.stringify(obj));
    }
}
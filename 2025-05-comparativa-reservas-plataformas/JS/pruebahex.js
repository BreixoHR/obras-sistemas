function stringToBinary(str) {
    return str
        .split('')
        .map(char => {
            return char.charCodeAt(0).toString(2).padStart(8, '0');
        })
        .join(' ');
}

var a= stringToBinary("***");
console.log(a);
var express = require('express')
, app = express()
, server = require('http').createServer(app)
, io = require('socket.io').listen(server);
    //express = require('express');
var gpio = require('./lib/gpio.js');

app.get('/', function (req, res) {
	res.sendfile(__dirname + '/index.html');
    });

server.listen(3050);
app.use("/static", express.static(__dirname + '/static'));

app.get('/off', function (req, res) {
    gpio.configure(15,'out');
    gpio.set(15,'1');
    res.send('OK');
    //res.sendfile(__dirname + '/index.html');
});

app.get('/on', function (req, res) {                                                                                                                                                                              
    gpio.configure(15,'out');
    gpio.set(15,'0');
    res.send('OK');
});                                 
                                                                                                                                                                              
app.get('/open', function (req, res) { 
    gpio.configure(15,'out');
    gpio.bounce(15,1000);
    res.send('OK');
});

io.sockets.on('connection', function(socket) {
 socket.on('open', function() {
        console.log('open');
	setTimeout (function () { socket.emit('reset')}, 1000 );
        gpio.configure(15,'out');
        gpio.bounce(15,1000);
        console.log('OK');
    });
});
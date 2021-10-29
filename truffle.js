var HDWalletProvider = require("truffle-hdwallet-provider");

var mnemonic = "mnemonic"

/*module.exports = {
  // See <http://truffleframework.com/docs/advanced/configuration>
  // for more about customizing your Truffle configuration!
  networks: {
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*" // Match any network id
	 },
	  ropsten: {
		  provider: function() {
			return new HDWalletProvider(mnemonic, "HTTP://127.0.0.1:7545")
		  },
		  //network_id: 3,       // Ropsten's id
		  //network_id: 5777,   //this is from Ganachi
		  gas: 5500000,        // Ropsten has a lower block limit than mainnet
		  confirmations: 2,    // # of confs to wait between deployments. (default: 0)
		  timeoutBlocks: 200,  // # of blocks before a deployment times out  (minimum/default: 50)
		  skipDryRun: true     // Skip dry run before migrations? (default: false for public nets )
	  }
  },	
  compilers: {
     solc: {
       version: "0.8.0"
     }
  }
};*/



let PrivateKeyProvider = require("truffle-privatekey-provider");
module.exports = {

    networks: {
		development: {
			  host: "127.0.0.1",
			  port: 7545,
			  network_id: "*" // Match any network id
		 },		
        kovan: {
            provider: new PrivateKeyProvider("Private Key", "Infura Link"),
            network_id: 42,
            from: "Public Key",
            gas: 8000000
        },
    },
    // Set default mocha options here, use special reporters etc.
    mocha: {
        timeout: 100000
    },
    // Configure your compilers
    compilers: {
        solc: {
            version: "0.8.0"
        }
    },
};


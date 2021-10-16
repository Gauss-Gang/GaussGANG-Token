// Sources flattened with hardhat v2.6.4 https://hardhat.org



// File contracts/dependencies/interfaces/IBEP20.sol


// BEP20 Interface that creates basic functions for a BEP20 token.
interface IBEP20 {
    
    
    // Returns the amount of tokens in existence.
    function totalSupply() external view returns (uint256);
    
    
    // Returns the token decimals.
    function decimals() external view returns (uint8);
    
    
    // Returns the token symbol.
    function symbol() external view returns (string memory);
    
    
    // Returns the token name.
    function name() external view returns (string memory);
    
    
    // Returns balance of the referenced 'account' address.
    function balanceOf(address account) external view returns (uint256);


    // Transfers an 'amount' of tokens from the caller's account to the referenced 'recipient' address. Emits a {Transfer} event. 
    function transfer(address recipient, uint256 amount) external returns (bool);
    
    
    // Transfers an 'amount' of tokens from the 'sender' address to the 'recipient' address. Emits a {Transfer} event.
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);


    // Returns the remaining tokens that the 'spender' address can spend on behalf of the 'owner' address through the {transferFrom} function.
    function allowance(address _owner, address spender) external view returns (uint256);
   
    
    // Sets 'amount' as the allowance of 'spender' then returns a boolean indicating result of operation. Emits an {Approval} event.
    function approve(address spender, uint256 amount) external returns (bool);

  
    // Emitted when `value` tokens are moved from one account address (`from`) to another (`to`). Note that `value` may be zero.
    event Transfer(address indexed from, address indexed to, uint256 value);


    // Emitted when the allowance of a `spender` for an `owner` is set by a call to {approve}. `value` is the new allowance.
    event Approval(address indexed owner, address indexed spender, uint256 value);
}



// File contracts/dependencies/utilities/Initializable.sol


/*  This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
    behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
    external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
    function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 
    TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
         possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 
    CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
             that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 */
abstract contract Initializable {
    
    // Indicates that the contract has been initialized.
    bool private _initialized;


    // Indicates that the contract is in the process of being initialized.
    bool private _initializing;


    //Modifier to protect an initializer function from being invoked twice.
    modifier initializer() {
        
        require(_initializing || !_initialized, "Initializable: contract is already initialized");
        bool isTopLevelCall = !_initializing;
        
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }
}



// File contracts/dependencies/utilities/Context.sol


// Provides information about the current execution context, including the sender of the transaction and its data.
abstract contract Context is Initializable  {
    
    
    // Empty initializer, to prevent people from mistakenly deploying an instance of this contract, which should be used via inheritance.
    function __Context_init() internal initializer {
        __Context_init_unchained();
    }
    
    // Empty internal initializer.
    function __Context_init_unchained() internal initializer {
    }


    function _msgSender() internal view virtual returns (address) {
        return (msg.sender);
    }
    
    
    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
    
    uint256[50] private __gap;
}



// File contracts/dependencies/access/Ownable.sol


// Provides a basic access control mechanism, where an account '_owner' can be granted exclusive access to specific functions by using the modifier `onlyOwner`.
abstract contract Ownable is Initializable, Context {
    
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


    // Initializes the contract, setting the deployer as the initial owner.
    function __Ownable_init() internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    
    // Initializes the contract, setting the deployer as the initial owner.
    function __Ownable_init_unchained() internal initializer {
        _owner = _msgSender();
        emit OwnershipTransferred(address(0), _owner);
    }
    

    // Returns the address of the current owner.
    function owner() public view returns (address) {
        return _owner;
    }

    
    // Throws if called by any account other than the owner.
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }


    // Transfers ownership of the contract to a new account (`newOwner`). Can only be called by the current owner.
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }


    // Internal function, transfers ownership of the contract to a new account (`newOwner`).
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}



// File contracts/dependencies/contracts/RefundVault.sol


/*  This contract is used for storing funds while a crowdsale is in progress.
        - should be initialized in the crowdsale contract, otherwise there are no safegaurds to prevent "owner" from closing the RefundVault and recieving all funds.
        - if crowdsale fails to reach the minimum cap (set in the crowdsale contract) by the close of the sale, a full refund to all buyers will be initiated.
        
        DEV-NOTE:   - a struct and array were used, in place of a mapping container, to hold buyer addresses and BNB amount.
                    - this allows "owner" to cover the cost of gas and refund all buyers in a single transaction.
*/
contract RefundVault is Ownable {

    // Creates enum to represent the State of the RefundVault.
    enum State { Active, Refunding, Completed }
    State private _state;

    // The sctruct will hold the address and BNB amount of each Buyer.
    struct Buyer {
        address payable wallet;
        uint256 amount;
    }

    // Array of all Buyers, used to keep track of each Buyer's address and amount of BNB spent.
    Buyer[] public buyers;

    // Address where BNB funds are collected.
    address payable public crowdsaleWallet;    

    event Completed();
    event RefundsIssued();
    event Refunded(address indexed beneficiary, uint256 jagerAmount);


    // Constructor sets the crowdsaleWallet adress and sets the State to Active.
    constructor(address payable _crowdsaleWallet) {
        require(_crowdsaleWallet != address(0), "RefundVault: address can not be 0.");
        __Ownable_init();
        crowdsaleWallet = _crowdsaleWallet;
        _state = State.Active;
    }


    // Returns the integer value of the current State; 0 = Active, 1 = Refunding, 2 = Completed.
    function currentState() public view returns (uint) {
        return uint(_state);
    }


    // Allows "owner" to keep track of the buyer's wallet address and amount of BNB sent in purchase; can only be called when in an Active State.
    function deposit(address payable _wallet, uint256 _amount) onlyOwner public {
        require(_state == State.Active, "RefundVault: State not currently active.");
        buyers.push(Buyer(_wallet, _amount));
    }


    // Allows "owner" to close the RefundVault, can only be called when in an Active State.
    function closeVault() onlyOwner public {
        require(_state == State.Active, "RefundVault: State not currently active.");
        crowdsaleWallet.transfer(address(this).balance);
        _state = State.Completed;
        emit Completed();        
    }


    // Allows "owner" to issue refunds should the minimum cap not be reached during the Crowdsale; can only be called when in an Active State.
    function issueRefunds() onlyOwner public {
        require(_state == State.Active, "RefundVault: State not currently active.");
        _state = State.Refunding;

        for (uint i = 0; i < buyers.length; i++) {
            require(buyers[i].amount > 0, "RefundVault: beneficiary amount can not be 0.");
            _refund(buyers[i]);
        }
        
        emit RefundsIssued();
    }

    
    // Internal function to facilitate the refund process per buyer.
    function _refund(Buyer storage beneficiary) internal {
        require(_state == State.Refunding, "RefundVault: State not currently Refunding.");
        beneficiary.wallet.transfer(beneficiary.amount);
        beneficiary.amount = 0;
        emit Refunded(beneficiary.wallet, beneficiary.amount);
    }
}



// File contracts/token/GaussCrowdsale.sol

/*  _____________________________________________________________________________

    GaussCrowdsale: Crowdsale for the Gauss Gang Ecosystem

    Deployed to: TODO

    MIT License. (c) 2021 Gauss Gang Inc. 

    _____________________________________________________________________________
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;


/*  The GuassCrowdsale allows buyers to purchase Gauss(GANG) tokens with BNB.
        - Crowdsale is Staged, where each Stage has a different exchange rate of BNB to Gauss(GANG) tokens.
        - Crowdsale is Refundable if the minimum cap amount is not reached by the end of the sale.
        - Crowdsale has a Maximum Purchase amount of 100 BNB.
        - The tokens bought in the Crowdsale can only be claimed after the completetion of the Crowdsale.
*/
contract GaussCrowdsale is Ownable {

    // Mapping that contains the addresses of each purchaser and the amount of tokens they will recieve.
    mapping(address => uint256) private balances;

    // The token being sold.
    IBEP20 private _token;

    // Refund Vault used to hold funds while Crowdsale is running
    RefundVault private refundVault;

    // How many Gauss(GANG) tokens a buyer will receive per BNB. (shown with the Gauss(GANG) decimals applied)
    uint256[] private rates = [
        6800000000000,      // 6,800 tokens per 1 BNB during stage 0
        5667000000000,      // 5,667 tokens per 1 BNB during stage 1
        4857000000000,      // 4,857 tokens per 1 BNB during stage 2
        4250000000000,      // 4,250 tokens per 1 BNB during stage 3
        3778000000000,      // 3,778 tokens per 1 BNB during stage 4
        3400000000000,      // 3,400 tokens per 1 BNB during stage 5
        3091000000000,      // 3,091 tokens per 1 BNB during stage 6
        2833000000000,      // 2,833 tokens per 1 BNB during stage 7
        2615000000000,      // 2,615 tokens per 1 BNB during stage 8
        2429000000000,      // 2,429 tokens per 1 BNB during stage 9
        2267000000000,      // 2,267 tokens per 1 BNB during stage 10
        2125000000000,      // 2,125 tokens per 1 BNB during stage 11
        2000000000000,      // 2,000 tokens per 1 BNB during stage 12
        1889000000000,      // 1,889 tokens per 1 BNB during stage 13
        1789000000000,      // 1,789 tokens per 1 BNB during stage 14
        1700000000000       // 1,700 tokens per 1 BNB during stage 15
    ];

    // Number of tokens per stage; the rate changes after each stage has been completed.
    uint256[] private stages = [
        100000,     // 100,000 tokens in stage 0
        250000,     // 150,000 tokens in stage 1
        500000,     // 250,000 tokens in stage 2
        750000,     // 250,000 tokens in stage 3
        1250000,    // 500,000 tokens in stage 4
        2000000,    // 750,000 tokens in stage 5
        2750000,    // 750,000 tokens in stage 6
        3500000,    // 750,000 tokens in stage 7
        4250000,    // 750,000 tokens in stage 8
        5000000,    // 750,000 tokens in stage 9
        6000000,    // 1,000,000 tokens in stage 10
        7000000,    // 1,000,000 tokens in stage 11
        9000000,    // 2,000,000 tokens in stage 12
        11000000,   // 2,000,000 tokens in stage 13
        13000000,   // 2,000,000 tokens in stage 14
        15000000    // 2,000,000 tokens in stage 15
    ];

    // Address where BNB funds are collected.
    address payable public crowdsaleWallet;

    // The amount, in Jager, that will represent the minimum amount before owner can release stored funds. (Set to 550 BNB)
    uint256 private minimumCap;

    // The max amount, in Jager, a buyer can purchase; used to prevent potential whales from buying up too many tokens at once.
    uint256 private purchaseCap;

    // Amount of Jager raised (BNB's smallest unit; BNB has 8 decimals).
    uint256 public jagerRaised;

    // Amount of remaining Gauss(GANG) tokens remaining in the GaussCrowdsale.
    uint256 public gaussSold;

    // Number indicating the current stage.
    uint256 public currentStage;

    // Start and end timestamps, between which investments are allowed.
    uint256 public startTime;
    uint256 public endTime;

    // A varaible to determine whether Crowdsale is closed or not.
    bool private _hasClosed;

    // Initializes an event that will be called after each token purchase.
    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);


    // Constructor sets takes the variables passed in and initializes are state variables. 
    constructor(uint256 _startTime, address _gaussAddress, address payable _crowdsaleWallet) {

        require(_startTime >= block.timestamp, "GaussCrowdsale: startTime can not be before current time.");
        require(_gaussAddress != address(0), "GaussCrowdsale: gaussAddress can not be Zero Address.");
        require(_crowdsaleWallet != address(0), "GaussCrowdsale: Crowdsale wallet can not be Zero Address.");
        require(rates.length == stages.length);

        __Ownable_init();
        startTime = _startTime;
        endTime = startTime + (30 days);
        crowdsaleWallet = _crowdsaleWallet;
        _token = IBEP20(_gaussAddress);
        refundVault = new RefundVault(crowdsaleWallet);
        minimumCap = (550 * 10**8);
        purchaseCap = (100 * 10**8);
        jagerRaised = 0;
        gaussSold = 0;
        currentStage = 0;
        _hasClosed = false;        
    }


    // Receive function to recieve BNB.
    receive() external payable {
        buyTokens(msg.sender);
    }


    /*  Allows one to buy or gift Gauss(GANG) tokens using BNB. 
            - Amount of BNB the buyer transfers must be lower than the "purchaseCap" of 100 BNB.
            - Either transfers BNB to RefundVault or crowdsaleWallet, depending on if "minimumCap" has been reached.
            - Keeps track of the token amounts purchased in the "balances" mapping, to be claimed after to Crowdsale is completed. */
    function buyTokens(address _beneficiary) public payable {
        uint256 jagerAmount = msg.value;
        _validatePurchase(_beneficiary, jagerAmount);
        _processPurchase(_beneficiary, jagerAmount);
        _transferBNB(payable(msg.sender), msg.value);
    }


    // Validation of an incoming purchase. Uses require statements to revert state when conditions are not met.
    function _validatePurchase(address _beneficiary, uint256 _jagerAmount) internal view {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "GaussCrowdsale: current time is either before or after Crowdsale period.");
        require(_hasClosed == false, "Crowdsale: sale is no longer open");
        require(_beneficiary != address(0), "GaussCrowdsale: beneficiary can not be Zero Address.");
        require(_jagerAmount != 0, "GaussCrowdsale: amount of BNB must be greater than 0.");
        require(_jagerAmount <= purchaseCap, "Crowdsale: amount of BNB sent must lower than 100");
        require((balances[_beneficiary] + _jagerAmount) <= purchaseCap, "Crowdsale: amount of BNB entered exceeds buyers purchase cap.");
    }


    // Adds the "tokenAmount" (amount of Gauss(GANG) tokens) to the beneficiary's balance.
    function _processPurchase(address _beneficiary, uint256 _jagerAmount) internal {

        // Calculates the token amount using the "jagerAmount" and the rate at the current stage.
        uint256 tokenAmount = ((_jagerAmount * rates[currentStage])/(10**8));
        
        // Addes the "tokenAmount" to the beneficiary's balance.
        balances[_beneficiary] = balances[_beneficiary] + tokenAmount;

        _updatePurchasingState(tokenAmount, _jagerAmount); 
        emit TokenPurchase(msg.sender, _beneficiary, _jagerAmount, tokenAmount);
    }


    // Updates the amount of tokens left in the Crowdsale; may change the stage if conditions are met.
    function _updatePurchasingState(uint256 _tokenAmount, uint256 _jagerAmount) internal {        
        gaussSold = gaussSold + _tokenAmount;
        jagerRaised = jagerRaised + _jagerAmount;
        
        if (gaussSold >= stages[currentStage]) {
            if (currentStage < stages.length) {
                currentStage = currentStage + 1;
            }
        }
    }


    // Tranfers the BNB recieved in purchase to either the Crowdsale Wallet or RefundVault, depending on whether the "minimumCap" has been met.
    function _transferBNB(address payable senderWallet, uint256 jagerAmount) internal {
        if (refundVault.currentState() == 2){
            crowdsaleWallet.transfer(jagerAmount);
        }
        else {
            payable(address(refundVault)).transfer(jagerAmount);
            refundVault.deposit(senderWallet, jagerAmount);
        }        
    }


    // Closes the RefundVault if the "minimumCap" has been reached. 
    function closeRefundVault() public onlyOwner() {
        require(jagerRaised >= minimumCap, "Crowdsale: minimum sale cap not reached");
        refundVault.closeVault();
    }


    // Allows "owner" to issue refunds to all buyers should the minimum cap amount not be reached by the completion of the Crowdsale.
    function issueRefunds() public onlyOwner() {
        require(block.timestamp >= endTime, "GaussCrowdsale: current time is before Crowdsale end time.");
        require(jagerRaised < minimumCap, "Crowdsale: minimum sale cap has been reached");
        refundVault.issueRefunds();
    }


    /*  Transfer remaining Gauss(GANG) tokens back to the "crowdsaleWallet" as well BNB earned if "minimumCap" is reached.
            NOTE:   - To be called at end of the Crowdsale to finalize and complete the Crowdsale.
                    - Can act as a backup in case the sale needs to be urgently stopped.
                    - Care should be taken when calling function as it could prematurely end the Crowdsale if accidentally called. */
    function finalizeCrowdsale() public onlyOwner() {
          
        // Send remaining tokens back to the admin.
        uint256 tokensRemaining = _token.balanceOf(address(this));
        _token.transfer(crowdsaleWallet, tokensRemaining);

        // Closes the Crowdsale and allows beneficiaries to withdrawl the purchased tokens.
        _hasClosed = true;

        // If "minimumCap" has been reached, transfer BNB raised to the Crowdsale wallet.
        if (address(this).balance >= minimumCap) {
            crowdsaleWallet.transfer(address(this).balance);
        }
    }


    // Can only be called once the Crowdsale has completed and the "owner" has finalized the Crowdsale.
    function withdrawTokens() public {
        
        require(_hasClosed == true, "Crowdsale: sale has not been closed.");
        uint256 amount = balances[msg.sender];
        
        require(amount > 0, "Crowdsale: can not withdrawl 0 amount.");
        balances[msg.sender] = 0;

        _token.transfer(msg.sender, amount);
    }
}

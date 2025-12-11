// SPDX-License-Identifier: AGPL-3.0  
pragma solidity >=0.8.26;

// @title Contract KipuBank Espirito Coin
// @author Lorenzo Piccoli
// @data 01/12/2025

// Imports
// Imports from OpenZeppelin Wizard page
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
using SafeERC20 for IERC20;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
// Chain-link data feed
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

// Declare custom errors
error NotOwner();
error ZeroAmount();
error Reentracy();
error NotAllowed();
error NotAllowedLimitCash();
error NonSufficientFunds();
error GetErrorOracleChainLink();
error MaxDepositedReached();
error MaxWithDrawReached();

// Declare the main contract
contract kipuSafe is Pausable, AccessControl {
    AggregatorV3Interface internal dataFeed;

    //from OpenZeppelin Wizard
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // Testnet address ETH/USDC
    //https://docs.chain.link/data-feeds/price-feeds/addresses?page=1&testnetPage=1&networkType=testnet&testnetSearch=ETH
    address private constant _priceFeedAddress = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

    // Admin and pauser roles setup
    constructor(address defaultAdmin, address pauser) 
    {
        // Define access roles
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, pauser);
        // Define data feeed oracle chain link
        dataFeed = AggregatorV3Interface(_priceFeedAddress);
        // Constructor to set the owner contract
        ownerContract = msg.sender;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // Get Decimals of data feed
    function getDecimalsFeed() private view returns (uint8) {
        return dataFeed.decimals();
    }

    // Get info with data feed  ETH/USDC
    function getChainlinkETH2USD() public view returns (int256) {
    (,int256 price,,,) = dataFeed.latestRoundData();
        if(price < 0) revert GetErrorOracleChainLink();
        return price;
    }

    // Function for convert token to usd
    function getTOKEN2USD(address token, uint256 amount) public view returns (uint256){
        uint8 tokenDecimals = IERC20Metadata(token).decimals();
        uint8 datafeedDecimals = getDecimalsFeed();
        // Change chain link by another datafeed
        // But my own token dont have this oracle in chain link
        uint256 Token2Usd = uint256(getChainlinkETH2USD());
        uint256 amountUsd = (amount * Token2Usd)/(10**(datafeedDecimals+tokenDecimals-6));
        return amountUsd;
    }

    // Function for convert ETH to USD
    function getETH2USD(uint256 amount) public view returns (uint256){
        uint8 tokenDecimals = IERC20Metadata(address(0)).decimals();
        uint8 datafeedDecimals = getDecimalsFeed();
        uint256 Eth2Usd = uint256(getChainlinkETH2USD());
        uint256 amountUsd = (amount * Eth2Usd)/(10**(datafeedDecimals+tokenDecimals-6));
        return amountUsd;
    }

    // Adress of the owner contract
    address public ownerContract;

    // Usuários podem sacar fundos de seu cofre, mas apenas até um limite fixo por transação, representado por uma variável imutável.
    uint256 immutable limitCash = 1 ether;

    // Number of deposits in contract
    uint16 private bankCap = 0;
    // Number of withdraws in contract
    uint16 private bankWithDraw = 0;
    // Global deposit limit for this contract
    uint16 constant BANK_CAP_LIMIT = 1000;

    // Mapping to track the maximum allowed cash for each user
    mapping(address => string) public annotationBank;
    // Mapping to track ERC20 token balances for each user
    mapping(address => mapping(address => uint256)) public balances;
    
    // Reentrancy guard variable
    bool private locked;

    // Declare custom events
    event Deposited(address indexed from, uint256 amount);
    event DepositedERC20(address indexed from, uint256 amount, address token);
    event AllowanceSet(address indexed who, uint256 amount);
    event Pulled(address indexed who, uint256 amount);
    event PulledERC20(address indexed who, uint256 amount, address token);
    event FallbackCalled(address indexed from, uint256 value, uint256 amount);
    event OwnerContractTransferred(address indexed ownerContract, address indexed newOwner);
    event MessageSet(address indexed who, string message);

    // Declare custom modifiers
    modifier onlyOwnerContract(){
        if(msg.sender != ownerContract) revert NotAllowed();
        _;
    }

    modifier noReentracy(){
        if(locked) revert Reentracy();
        locked = true;
        _;
        locked = false;
    }

    //Eventos devem ser emitidos tanto em depósitos quanto em saques bem-sucedidos.
    // Modification to receive ether into the contract directly
    receive() external payable{
        //Checks
        if (msg.value == 0) revert ZeroAmount();
        if (bankCap > BANK_CAP_LIMIT) revert MaxDepositedReached();
        //Effects
        balances[address(0)][msg.sender] += msg.value;
        incrementDeposits();
        //Interactions
        emit Deposited(msg.sender, msg.value);
    }
    // Funtion to deposit ether into the contract
    function depositNative() external payable noReentracy(){
        //Check
        if (msg.value == 0) revert ZeroAmount();
        if (bankCap > BANK_CAP_LIMIT) revert MaxDepositedReached();
        //Effects
        balances[address(0)][msg.sender] += msg.value;
        incrementDeposits();
        //Interactions
        emit Deposited(msg.sender, msg.value);
    }

    // Deposit of token ERC20
    function depositERC20(address token, uint256 amount) external payable noReentracy {
        //Check
        if (msg.value == 0) revert ZeroAmount();
        //Effects
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        balances[token][msg.sender] += amount;
        //Interactions
        emit DepositedERC20(msg.sender, msg.value, token);
    }

    // Function for withdraw ether from proprietary
    function withDrawNative(uint256 amount) external noReentracy{
        //Check
        if (amount == 0) revert ZeroAmount();
        if (amount > limitCash) revert NotAllowedLimitCash();
        if (amount > balances[address(0)][msg.sender]) revert NonSufficientFunds();

        //Effects
        // address(0) is equal native token (ether)
        balances[address(0)][msg.sender] -= amount;
        incrementWithDraws();

        //Interactions
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
        emit Pulled(msg.sender, amount);
    }

    // Withdraw tokens ERC20
    function withdrawERC20(address token, uint256 amount) external noReentracy {
        //Check
        if (amount > balances[address(0)][msg.sender]) revert NonSufficientFunds();
        //Effects
        balances[token][msg.sender] -= amount;
        IERC20(token).safeTransfer(msg.sender, amount);
        //Interactions
        emit PulledERC20(msg.sender, amount, token);
    }

    // Function for put a message in contract
    function SetannotationBank(string calldata _inputString) external payable noReentracy{
        //Copy de string of `calldata` to `storage`
        //Cost of 0.1 ether
        //Check
        if (balances[address(0)][msg.sender] == 0) revert ZeroAmount();
        if (balances[address(0)][msg.sender] < 0.1 ether) revert NonSufficientFunds();
        //Effects
        balances[address(0)][msg.sender] -= 0.1 ether;
        balances[address(0)][ownerContract] += 0.1 ether;
        annotationBank[msg.sender] = _inputString;
        //Interactions
        emit MessageSet(msg.sender, _inputString);
    }

    // Funtion fallback to handle calls to non-existent functions
    fallback() external payable{
        emit FallbackCalled(msg.sender, msg.value, address(this).balance);
    }

    // Consultar saldo
    function balanceOf(address token, address user) external view returns (uint256) {
        uint256 amount = balances[token][user];
        return amount;
    }
    // Function to get max allowed cash for a user's withdraw
    function balanceOfETH(address who) external view returns (uint256) {
        return balances[address(0)][who];
    }
    // Function to get contract balance and stats
    function infoBalanceContract() public view returns (uint balance, uint16 deposits, uint16 withdraws, uint8 decimals){
        balance = address(this).balance;
        deposits = bankCap;
        withdraws = bankWithDraw;
        decimals = 18;
    }

    // Function for get balance of contract in USD
    function getBalanceInUSD() public view returns (uint256) {
        uint256 balanceETH = address(this).balance;
        uint8 datafeedDecimals = getDecimalsFeed();
        int256 price = getChainlinkETH2USD();
        uint256 balanceUSDT = (balanceETH * (uint256(price)))/(10**(datafeedDecimals+12)); 
        return balanceUSDT;
    }

    // Function to get contract balance and stats in USDT
    function infoBalanceContractUSD() public view returns (uint balance, uint16 deposits, uint16 withdraws, uint8 decimals){
        balance = getBalanceInUSD();
        deposits = bankCap;
        withdraws = bankWithDraw;
        decimals = 8;
    }

    // Function to change the owner contract
    function changeOwner(address who) external onlyOwnerContract noReentracy{
        //Check
        if (who == address(0)) revert NotAllowed();
        //Effects
        ownerContract = who;
        //Interactions
        emit OwnerContractTransferred(ownerContract, who);
    }

    //Function to increment number of deposits
    function incrementDeposits() private {
        bankCap += 1;
    }

    //Function to increment number of withdraws
    function incrementWithDraws() private {
        bankWithDraw += 1;
    }

}
// SPDX-License-Identifier: AGPL-3.0  
pragma solidity >=0.8.26;

// @title Contract Kipu Bank V3 Espirito Coin
// @author Lorenzo Piccoli
// @data 11/12/2025

// Imports
// Imports from OpenZeppelin Wizard page
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
using SafeERC20 for IERC20; // Recommended use safeERC20
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
// Chain-link data feed
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
// Imports of Universal Router and Permit2
import {IUniversalRouter} from "@uniswap/universal-router/contracts/interfaces/IUniversalRouter.sol";
import {IPermit2} from "@uniswap/v4-periphery/lib/permit2/src/interfaces/IPermit2.sol";
// import interfaces & base helpers do Uniswap v4
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@uniswap/v4-core/src/interfaces/callback/IUnlockCallback.sol";
// Import Periphery Helpers
import {SafeCallback} from "@uniswap/v4-periphery/src/base/SafeCallback.sol";
import {DeltaResolver} from "@uniswap/v4-periphery/src/base/DeltaResolver.sol";
// Imports from PointsHook eth-ufes
import {BaseHook} from "@uniswap/v4-periphery/src/utils/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol"; // CORRETO

import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
using BalanceDeltaLibrary for BalanceDelta;

// Declare custom errors
error NotOwner();
error ZeroAmount();
error Reentracy();
error NotAllowed();
error NotAllowedToken();
error NotAllowedLimitCash();
error NonSufficientFunds();
error GetErrorOracleChainLink();
error MaxDepositedReached();
error MaxBankCapReached();
error MaxWithDrawReached();
error SlippageTooHigh();
error TokenCannotBeUSDC();

// Declare the main contract
contract kipuSafe is Pausable, AccessControl {
    AggregatorV3Interface internal dataFeed;
    

    //from OpenZeppelin Wizard
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // Allowed token in kipu bank
    address public allowedToken;

    // Uniswap V4 constants for swap
    uint160 public constant MIN_SQRT_RATIO = 4295128739;
    uint160 public constant MAX_SQRT_RATIO =  1461446703485210103287273052203988822378723970342;

    // Testnet address ETH/USDC
    // Link for get address data feed for a given coin
    // https://docs.chain.link/data-feeds/price-feeds/addresses?page=1&testnetPage=1&networkType=testnet&testnetSearch=ETH
    address private constant _priceFeedAddress = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

    address private constant _router = 0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD;
    address private constant _permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;


    IUniversalRouter public immutable universalRouter;
    IPermit2 public immutable permit2;

    IPoolManager public immutable poolManager;


    // Admin and pauser roles setup
    // Allowed token in kipu bank
    constructor(address _defaultAdmin, address _pauser, address _allowedToken) 
    {
        // Define access roles
        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
        _grantRole(PAUSER_ROLE, _pauser);
        // Define data feeed oracle chain link
        dataFeed = AggregatorV3Interface(_priceFeedAddress);
        // Define allowed token supported in kipu bank
        allowedToken = _allowedToken;
        // Constructor to set the owner contract
        ownerContract = msg.sender;

        // Universal Router and Permit2 setup
        universalRouter = IUniversalRouter(_router);
        permit2 = IPermit2(_permit2);
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


    function TEST_DEPOSIT_ONLY(address tokenIn, uint160 amountIn) external {
        // Tenta puxar o dinheiro usando Permit2
        permit2.transferFrom(msg.sender, address(this), amountIn, tokenIn);
        
        // Se chegar aqui, funcionou! O dinheiro fica no contrato.
    }

    // Get info with data feed  ETH/USDC
    function getChainlinkETH2USD() public view returns (int256) {
    (,int256 price,,,) = dataFeed.latestRoundData();
        if(price < 0) revert GetErrorOracleChainLink();
        return price;
    }

    // Function for convert token to usd
    function getTOKEN2USD(address token, uint256 amount) public view returns (uint256){
        // Checks
        if(token != allowedToken) revert NotAllowedToken();
        uint8 tokenDecimals = IERC20Metadata(token).decimals();
        uint8 datafeedDecimals = getDecimalsFeed();
        // Change chain link by another datafeed
        // But my own token dont have this oracle in chain link
        // I will use ETH/USD for test
        uint256 Token2Usd = uint256(getChainlinkETH2USD());
        uint256 amountUsd = (amount * Token2Usd)/(10**(datafeedDecimals+tokenDecimals-6));
        return amountUsd;
    }

    // Function for convert ETH to USD
    function getETH2USD(uint256 amount) public view returns (uint256){
        uint8 tokenDecimals = 18;
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
    uint16 private bankTransactions = 0;
    // Number of withdraws in contract
    uint16 private bankWithDraw = 0;
    // Current bank cap in USDC
    uint256 private bankCap = 0;
    // Global deposit limit for this contract
    uint16 constant BANK_TRANSACTIONS_LIMIT = 1000;
    // Global limit for USDC of this contract (1 MILLION DOLLARS)
    uint256 constant BANK_MAX_CAP_USDC = 1_000_000 * 10**6;

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
    event SwapExecuted(address indexed who, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);    

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
        if (bankTransactions > BANK_TRANSACTIONS_LIMIT) revert MaxDepositedReached();
        if (bankCap > BANK_MAX_CAP_USDC) revert MaxBankCapReached();

        //Effects
        balances[address(0)][msg.sender] += msg.value;
        incrementDeposits();
        //Interactions
        emit Deposited(msg.sender, msg.value);
    }

    // Address of token Sepolia USDC
    address constant USDC_SEPOLIA = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

    // Data structure to hold callback parameters
    struct CallbackData {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint128 amountOutMin;
    }

    // Function for receive arbitrary token and swap to USDC in the bank
    function depositArbitraryToken(
        address tokenIn,
        uint160 amountIn,
        uint128 amountOutMin
    ) external {
        // Checks
        if(tokenIn != USDC_SEPOLIA) revert TokenCannotBeUSDC();
        // Effects
        // Get the tokens from the user using Permit2
        permit2.transferFrom(msg.sender, address(this), amountIn, tokenIn);
        // Manipulate the callback data
        bytes memory data = abi.encode(CallbackData({
            tokenIn: tokenIn,
            tokenOut: USDC_SEPOLIA, // Set tokenOut to USDC_SEPOLIA
            amountIn: amountIn,
            amountOutMin: amountOutMin
        }));
        // Execute the unlock on the PoolManager, triggering the callback
        poolManager.unlock(data);
    }

    // Callback function invoked by PoolManager after unlock
    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        // Checks
        require(msg.sender == address(poolManager), "Only PoolManager");

        // Effects
        // Decode the callback data
        CallbackData memory params = abi.decode(data, (CallbackData));

        // Call the internal swap function
        _swapExactInputSingle(
            params.tokenIn,
            params.tokenOut,
            params.amountIn,
            params.amountOutMin
        );

        return "";
    }

    // Function to execute swap exact input single
    function _swapExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint128 amountOutMin
    ) internal returns (uint256 amountOut) {
        // Role of swap 
        bool zeroForOne = tokenIn < tokenOut;
        (Currency currency0, Currency currency1) = zeroForOne
            ? (Currency.wrap(tokenIn), Currency.wrap(tokenOut))
            : (Currency.wrap(tokenOut), Currency.wrap(tokenIn));

        // Define PoolKey parameters
        // 3000 for fee and 60 for tickSpacing is default
        PoolKey memory key = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000,       
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });

        // Define SwapParams parameters
        SwapParams memory params = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: -int256(amountIn),
            sqrtPriceLimitX96: zeroForOne ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1
        });

        // Execute the swap via PoolManager
        // 'delta' diz quem deve quanto para quem
        BalanceDelta delta = poolManager.swap(key, params, "");

        // Settle the swap based on the delta
        if (zeroForOne) {
            // Cenário: TokenIn é currency0 (Menor endereço)
            // delta.amount0() será negativo (Dívida que temos que pagar ao Manager)
            // delta.amount1() será positivo (Lucro que temos a receber)

            // 1. Pagamos a entrada (TokenIn)
            IERC20(tokenIn).transfer(address(poolManager), uint128(-delta.amount0()));
            
            // 2. Recebemos a saída (USDC)
            poolManager.take(currency1, address(this), uint128(delta.amount1()));
            
            amountOut = uint128(delta.amount1());

        } else {
            // Cenário: TokenIn é currency1 (Maior endereço)
            
            // 1. Pagamos a entrada (TokenIn)
            IERC20(tokenIn).transfer(address(poolManager), uint128(-delta.amount1()));

            // 2. Recebemos a saída (USDC)
            poolManager.take(currency0, address(this), uint128(delta.amount0()));

            amountOut = uint128(delta.amount0());
        }

        // Slippage check
        // For dont waste money if slippage is too high

        if(amountOut >= amountOutMin) revert SlippageTooHigh();
        emit SwapExecuted(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    // Funtion to deposit ether into the contract
    function depositNative() external payable noReentracy(){
        //Check
        if (msg.value == 0) revert ZeroAmount();
        if (bankTransactions > BANK_TRANSACTIONS_LIMIT) revert MaxDepositedReached();
        if (bankCap > BANK_MAX_CAP_USDC) revert MaxBankCapReached();
        //Another check now for bank cap
        uint256 depositUSD = getETH2USD(msg.value);
        uint256 newTotalCapBank = getBankCapUSD() + depositUSD;
        if (newTotalCapBank > BANK_MAX_CAP_USDC) revert MaxBankCapReached();
        //Effects
        balances[address(0)][msg.sender] += msg.value;
        incrementDeposits();
        //Interactions
        emit Deposited(msg.sender, msg.value);
    }

    // Deposit of token ERC20
    function depositERC20(address token, uint256 amount) external payable noReentracy {
        //Check
        if (bankCap > BANK_MAX_CAP_USDC) revert MaxBankCapReached();
        //if (token != allowedToken) revert NotAllowedToken();
        //Another check now for bank cap
        uint256 depositUSD = getTOKEN2USD(token, amount);
        uint256 newTotalCapBank = getBankCapUSD() + depositUSD;
        if (newTotalCapBank > BANK_MAX_CAP_USDC) revert MaxBankCapReached();
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
        deposits = bankTransactions;
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
        deposits = bankTransactions;
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
        bankTransactions += 1;
    }

    //Function to increment number of withdraws
    function incrementWithDraws() private {
        bankWithDraw += 1;
    }

    //Function to increment number of withdraws
    function getBankCapUSD() private returns (uint256) {
        bankCap = getBalanceInUSD();
        return bankCap;
    }

    /// @notice Retorna as permissões do hook
    /// @dev Este hook implementa afterSwap e afterAddLiquidity
    function getHookPermissions() public pure returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: false,
            afterSwap: true, // ✅ Implementamos este hook
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }




}
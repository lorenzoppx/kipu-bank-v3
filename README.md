# kipu-bank-v2

O smart contract *kipuSafeV2* foi deployado na rede de teste *SepoliaETH* via foundry no seguinte endereço:
```
0x6b522d43d165a4383bd0f2f61ac87de4bf29df42
```
Pode ser consultado no explorador de blocos *EtherScan*:
```
https://sepolia.etherscan.io/address/0x6b522d43d165a4383bd0f2f61ac87de4bf29df42
```
Contrato deployado via:
```
forge create --rpc-url $ALCHEMY_SEPOLIA_RPC --private-key $PRIVATE_KEY --verify --etherscan-api-key $ETHSCAN_KEY --broadcast script/safe.sol:kipuSafe --constructor-args <<arg1-address-admin>>  <<arg2-address-pauser>>
```
# Controle de Acesso

Esse contrato possui controle de acesso via contratos da OpenZeppelin segundo *Pausable e AcessControl*, cujos papéis são definidos no ato de *deploy* do *smart contract*.

# Oráculo de Dados

Esse contrato utiliza de Data Feed da ChainLink na *testnet* Sepolia para adquirir o câmbio de ETH para USD. 
```
0x694AA1769357215DE4FAC081bf1f309aDC325306
```
# Padrão checks-effects-interactions

Esse contrato aplica o padrão conhecido como checks-effects-interactions, para otimização de gas e tratamento seguro das transferências realizadas.

# Suporte Multi-token

Esse contrato possui suporte multi-token via contratos da OpenZeppelin segundo *ERC-20*, permitindo diferentes funcionalidades de depósito e saque.

# Interação com o contrato

O contrato permite interação por meio das seguintes funções:

  
  - depositFunds(): Funtion to deposit ether into the contract <br>
  - <b>depositERC20()</b>: Funtion to deposit token ERC20 into the contract <br>
  - withDrawNative(): Function for withdraw ether from proprietary <br>
  - <b>withDrawERC20()</b>: Function for withdraw token ERC20 from proprietary <br>
  - <b>balanceOf()</b>: Function for check amount for specific token ERC20 in given address<br>
  - <b>balanceOfETH()</b>: Function for check amount for ETH in given address<br>
  - SetannotationBank(): Function for set a string in proprietary account for a cost of 0.1 ether <br>
  - infoBalanceContract(): Function to get contract balance, stats and decimal <br>
  - <b>infoBalanceContractUSD()</b>: Function to get contract balance in USD, stats and decimal <br>
  - changeOwner(): Function to change the owner contract <br>

# Eventos

O contrato possui os seguintes alertas de evento: 

  - event Deposited(); <br>
  - event AllowanceSet(); <br>
  - event Pulled(); <br>
  - event FallbackCalled(); <br>
  - event OwnerContractTransferred(); <br>
  - event MessageSet(); <br>

# Erros

O contrato possui os seguintes erros que podem ser invocados: 

- error NotOwner(); <br>
- error ZeroAmount(); <br>
- error Reentracy(); <br>
- error NotAllowed(); <br>
- error NotAllowedLimitCash(); <br>
- error NonSufficientFunds(); <br>
- error GetErrorOracleChainLink(); <br>
- error MaxDepositedReached(); <br>
- error MaxWithDrawReached(); <br>

# Forge Dependencies

```
forge install OpenZeppelin/openzeppelin-contracts
forge install smartcontractkit/chainlink-brownie-contracts
forge install foundry-rs/forge-std
```

# Forge Developments Commands

```
forge build
forge test
forge fmt
forge snapshot
```
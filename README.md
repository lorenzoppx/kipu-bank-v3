# kipu-bank-v3

O smart contract *kipuSafeV3* foi deployado na rede de teste *SepoliaETH* via foundry no seguinte endereço:
```
0x6Aa781678F7BADA4f8BAa3fafE3c38cAAb1f7F57
```
Pode ser consultado no explorador de blocos *EtherScan*:
```
https://sepolia.etherscan.io/address/0x6Aa781678F7BADA4f8BAa3fafE3c38cAAb1f7F57
```
Contrato deployado via script:
```
forge script script/Kipu.s.sol:DeployKipu --rpc-url $ALCHEMY_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ETHSCAN_KEY -vvvvv
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

# Limite bank cap in USD

Esse contrato possui um limite de capitalização do banco kipu implementado de 1 milhão de dólares, na tentativa de depósito todos os tokens ERC20 e ETH são convertidos ao respectivo montante em dólar e o limite é verificado na realização da transação.

# Funcionalidades do KipuBankV3

Esse contrato herda todo o supote a depósitos, saques, consultas de oráculo de preço e lógica do proprietário(owner).


# Depósito de qualquer Token ERC20

Qualquer token suportado pela Uniswap é aceito como depósito, sobre esse token realiza-se o auto-swap para ETH na ação do depósito.

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
- error MaxBankCapReached(); <br>

# Forge Dependencies

```
forge install foundry-rs/forge-std
```

# Npm Dependencies

```
npm install @openzeppelin/contracts 
npm install @chainlink/contracts 
npm install @uniswap/v4-core 
npm install @uniswap/v4-periphery 
npm install @uniswap/universal-router
```

# Forge Developments Commands

```
forge build
forge test
forge fmt
forge snapshot

```

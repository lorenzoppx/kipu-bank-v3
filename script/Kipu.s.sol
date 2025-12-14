// SPDX-License-Identifier: MIT
pragma solidity >=0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {kipuSafe} from "../src/Kipu.sol"; 

contract DeployKipu is Script {
    function run() external {
        // 1. Ler variáveis de ambiente
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Endereços para o construtor
        address admin = vm.envAddress("ADMIN_ADDRESS");
        address pauser = vm.envAddress("PAUSER_ADDRESS");
        address allowedToken = vm.envAddress("ALLOWED_TOKEN_ADDRESS");

        // 2. Iniciar a transmissão da transação
        vm.startBroadcast(deployerPrivateKey);

        // 3. Deploy do contrato
        // Passando: Admin, Pauser, Token Permitido
        kipuSafe bank = new kipuSafe(admin, pauser, allowedToken);

        console.log("Contrato KipuSafe deployado em:", address(bank));

        // 4. Parar transmissão
        vm.stopBroadcast();
    }
}
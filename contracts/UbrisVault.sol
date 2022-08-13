// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract UbrisVault {
    //// Variables

    /// Enums

    // - Etat des stratégies, OPEN ou CLOSE
    enum StrategyState {
        OPEN,
        CLOSE
    } // 0 : OPEN, 1 : CLOSE

    /// Structures

    // - Structure des stratégies (ajouter le nombre de user dedans ?)
    struct Strategy {
        string name;
        StrategyState strategyState;
        bool isWhitelist;
    }

    /// Mapping

    // - Liste des users entrés dans le protocole et avec combien de tokens (user => (token => amount))
    mapping(address => mapping(address => uint256)) private s_totalBalances;

    // - Liste des users entrés dans quelle stratégie et avec combien de tokens

    // - Liste des différentes stratégies whitelisté
    mapping(address => Strategy) private s_strategies;

    //// Events

    // - User entre dans une nouvelle stratégies ?

    // - Le yield des stratégies a été récupéré ?

    // - Une nouvelle stratégie a été ajoutée à la whitelist ?

    // - Une stratégie a été retirée de la whitelist ?

    //// Méthodes

    /// Gestion des fonds des users

    // - Récupère l'argent des users
    // - Import OpenZeppelin ERC20, ask for address of the ERC20 to deposit, call transferFrom(), check for approve() function to implement
    function depositFunds(address tokenAddress, uint256 amount) public payable {
        ERC20 token = ERC20(tokenAddress);
        token.transferFrom(msg.sender, address(this), amount);
        s_totalBalances[msg.sender][tokenAddress] += amount;
    }

    // - Retire l'argent des users
    function withdrawFunds(address tokenAddress, uint256 amount) public {
        // Plus tard vérifier qu'y'a assez d'argent dans ce contrat pour retirer et que tout ne soit pas dans une stratégie
        require(s_totalBalances[msg.sender][tokenAddress] >= amount, "You can't withdraw more than your wallet funds.");
        ERC20 token = ERC20(tokenAddress);
        token.transfer(msg.sender, amount);
        s_totalBalances[msg.sender][tokenAddress] -= amount;
    }

    // - Envoi l'argent d'un user dans une stratégie

    // - Retire l'argent d'un user d'une stratégie

    /// Gestion des stratégies

    // - Ajoute une nouvelle stratégie (onlyOwner ?)
    function addStrategy(address strategyAddress, string memory name) public {
        require(!s_strategies[strategyAddress].isWhitelist, "This strategy is already whitelist.");
        Strategy memory strategy;
        strategy.name = name;
        strategy.strategyState = StrategyState.OPEN; // = OPEN
        strategy.isWhitelist = true;

        s_strategies[strategyAddress] = strategy;

        // emit newStrategy()
    }

    // - Retire une stratégie (onlyOwner ?) (Problème c'est que si je fais comme ça, une stratégie qui a été retirer pourra plus jamais être remise)
    function removeStrategy(address strategyAddress) public view {
        Strategy memory strategy = s_strategies[strategyAddress];
        require(strategy.isWhitelist, "This strategy has already been removed.");

        strategy.strategyState = StrategyState.CLOSE; // = CLOSE
        strategy.isWhitelist = false;

        // emit removeStrategyFromWhitelist()
    }

    // - Met en pause une stratégie (onlyOwner ?)
    function pauseStrategy(address strategyAddress) public view {
        Strategy memory strategy = s_strategies[strategyAddress];
        require(strategy.strategyState == StrategyState.OPEN, "This strategy is already in pause.");
        strategy.strategyState = StrategyState.CLOSE; // = CLOSE
    }

    // - Réactive une stratégie (onlyOwner ?)
    function resumeStrategy(address strategyAddress) public view {
        Strategy memory strategy = s_strategies[strategyAddress];
        require(strategy.strategyState == StrategyState.CLOSE, "This strategy is already active.");
        strategy.strategyState = StrategyState.OPEN; // = OPEN
    }

    // - Dis aux stratégies de récupérer le yield

    /// Get functions

    // - Récupérer la liste d'adresses de toutes les stratégies

    // - Récupérer la balance totale du protocole pour un token en particulier (hors stratégies ici)
    function getTokenBalance(address tokenAddress) public view returns (uint256) {
        ERC20 token = ERC20(tokenAddress);
        return token.balanceOf(address(this));
    }

    // - Récupérer la balance d'une stratégie en particulier (voir de toutes les stratégies en même temps si jamais)

    // - Récupérer la balance d'un utilisateur en particulier pour un token en particulier
    function getUserBalance(address userAddress, address tokenAddress) public view returns (uint256) {
        return s_totalBalances[userAddress][tokenAddress];
    }

    // - Récupérer l'adresse ou les noms des stratégies dans lesquelles est un utilisateur en particulier

    // - Récupérer la liste d'adresses de tous les utilisateurs du protocole

    // - Récupérer la liste d'adresses de tous les utilisateurs d'une stratégie

    // - Récupérer l'état d'une stratégie (OPEN | CLOSE)
    function getStrategyState(address strategyAddress) public view returns (StrategyState) {
        return s_strategies[strategyAddress].strategyState;
    }

    function testInteract(uint256 number) public pure returns (uint256) {
        number++;

        return number;
    }
}

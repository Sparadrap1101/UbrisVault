// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IStrategy.sol";

contract UbrisVault is Ownable {
    //// Variables

    /// Classic variables

    /// Enums

    // - Etat des stratégies, OPEN ou CLOSE
    enum StrategyState {
        CLOSE,
        OPEN
    } // 0 : CLOSE, 1 : OPEN

    /// Structures

    // - Structure des stratégies (ajouter le nombre de user dedans ? Utiliser les events plutôt)
    struct Strategy {
        string name;
        StrategyState strategyState;
        bool isWhitelist;
    }

    /// Mapping

    // - Liste des users entrés dans le protocole et avec combien de tokens (user => (token => amount))
    mapping(address => mapping(address => uint256)) private s_totalBalances;

    // - Liste des users entrés dans quelle stratégie et avec combien de tokens (Use les events ?)

    // - Liste des différentes stratégies whitelisté
    mapping(address => Strategy) private s_strategies;

    //// Events

    // - Le yield des stratégies a été récupéré (Récupérer le montant du Yield récolté aussi ?)
    event YieldRecolted(address indexed strategyAddress, string indexed name);

    // - Une nouvelle stratégie a été ajoutée à la whitelist
    event NewStrategy(address indexed strategyAddress, string indexed name);

    // - Une stratégie a été retirée de la whitelist
    event StrategyRemoved(address indexed strategyAddress, string indexed name);

    // - Une stratégie à été mise en pause
    event StrategyPaused(address indexed strategyAddress, string indexed name);

    // - Une stratégie à été resumed
    event StrategyResumed(address indexed strategyAddress, string indexed name);

    // - Un utilisateur est entré dans une stratégie
    event UserEnterStrategy(
        address indexed strategyAddress,
        string indexed name,
        address indexed userAddress,
        uint256 amount
    );

    // - Un utilisateur est sorti d'une stratégie
    event UserExitStrategy(
        address indexed strategyAddress,
        string indexed name,
        address indexed userAddress,
        uint256 amount
    );

    // - Un utilisateur est entré dans le protocole
    event UserEnterProtocol(address indexed userAddress, address indexed tokenAddress, uint256 amount);

    // - Un utilisateur est sorti du protocole
    event UserExitProtocol(address indexed userAddress, address indexed tokenAddress, uint256 amount);

    //// Méthodes

    /// Gestion des fonds des users

    // - Récupère l'argent des users
    function depositFunds(address tokenAddress, uint256 amount) public payable {
        require(tokenAddress != address(0), "This token doesn't exist.");
        ERC20 token = ERC20(tokenAddress);
        token.transferFrom(msg.sender, address(this), amount);
        s_totalBalances[msg.sender][tokenAddress] += amount;

        emit UserEnterProtocol(msg.sender, tokenAddress, amount);
    }

    // - Retire l'argent des users
    function withdrawFunds(address tokenAddress, uint256 amount) public {
        require(tokenAddress != address(0), "This token doesn't exist.");
        require(s_totalBalances[msg.sender][tokenAddress] >= amount, "You can't withdraw more than your wallet funds.");
        ERC20 token = ERC20(tokenAddress);
        require(token.balanceOf(address(this)) >= amount, "Not enough funds, please withdraw from the strategy before.");

        token.transfer(msg.sender, amount);
        s_totalBalances[msg.sender][tokenAddress] -= amount;

        emit UserExitProtocol(msg.sender, tokenAddress, amount);
    }

    // - Envoi l'argent d'un user dans une stratégie
    function enterStrategy(
        address strategyAddress,
        address tokenAddress,
        uint256 amount
    ) public {
        require(strategyAddress != address(0), "This strategy doesn't exist.");
        require(tokenAddress != address(0), "This token doesn't exist.");
        require(s_strategies[strategyAddress].isWhitelist, "This strategy is not on whitelist.");
        require(s_strategies[strategyAddress].strategyState == StrategyState.OPEN, "This strategy is not open.");
        IStrategy strategyInterface = IStrategy(strategyAddress);

        require(strategyInterface.getTokenToDeposit() == tokenAddress, "This token is not accepted on this strategy.");
        require(s_totalBalances[msg.sender][tokenAddress] >= amount, "You don't have enough funds to enter this strategy.");
        ERC20 token = ERC20(tokenAddress);

        token.approve(strategyAddress, amount); // En pratique on pourrait mettre amount très grand et faire un if
        strategyInterface.enterStrategy(tokenAddress, msg.sender, amount);

        s_totalBalances[msg.sender][tokenAddress] -= amount;

        emit UserEnterStrategy(strategyAddress, s_strategies[strategyAddress].name, msg.sender, amount);
    }

    // - Retire l'argent d'un user d'une stratégie
    function exitStrategy(address strategyAddress, uint256 amount) public {
        require(strategyAddress != address(0), "This strategy doesn't exist.");
        IStrategy strategyInterface = IStrategy(strategyAddress);
        require(strategyInterface.getUserBalance(msg.sender) >= amount, "You don't have enough funds to withdraw.");
        // En fonction des stratégies tester si la liquidité peut être retiré ou si elle est dans des pools
        // par exemple (à faire plutôt côté stratégie).

        strategyInterface.exitStrategy(msg.sender, amount);
        s_totalBalances[msg.sender][strategyInterface.getTokenToDeposit()] += amount;

        emit UserExitStrategy(strategyAddress, s_strategies[strategyAddress].name, msg.sender, amount);
    }

    /// Gestion des stratégies

    // - Ajoute une nouvelle stratégie
    function addStrategy(address strategyAddress, string memory name) public onlyOwner {
        require(strategyAddress != address(0), "This strategy doesn't exist.");
        require(!s_strategies[strategyAddress].isWhitelist, "This strategy is already whitelist.");
        // Peut être testé si on est bien l'owner de la stratégie plus tard.

        Strategy memory strategy;
        // Attention car si le name est le même pour plusieurs stratégies et ça peut poser prbl pour les events
        strategy.name = name;
        strategy.strategyState = StrategyState.OPEN;
        strategy.isWhitelist = true;

        s_strategies[strategyAddress] = strategy;

        emit NewStrategy(strategyAddress, name);
    }

    // - Retire une stratégie
    function removeStrategy(address strategyAddress) public onlyOwner {
        require(strategyAddress != address(0), "This strategy doesn't exist.");
        Strategy storage strategy = s_strategies[strategyAddress];
        require(strategy.isWhitelist, "This strategy has already been removed.");

        strategy.strategyState = StrategyState.CLOSE;
        strategy.isWhitelist = false;

        emit StrategyRemoved(strategyAddress, strategy.name);
    }

    // - Met en pause une stratégie
    function pauseStrategy(address strategyAddress) public onlyOwner {
        require(strategyAddress != address(0), "This strategy doesn't exist.");
        Strategy storage strategy = s_strategies[strategyAddress];
        require(strategy.isWhitelist, "This strategy is not whitelist.");
        require(strategy.strategyState == StrategyState.OPEN, "This strategy is already in pause.");

        strategy.strategyState = StrategyState.CLOSE;

        emit StrategyPaused(strategyAddress, strategy.name);
    }

    // - Réactive une stratégie
    function resumeStrategy(address strategyAddress) public onlyOwner {
        require(strategyAddress != address(0), "This strategy doesn't exist.");
        Strategy storage strategy = s_strategies[strategyAddress];
        require(strategy.isWhitelist, "This strategy is not whitelist.");
        require(strategy.strategyState == StrategyState.CLOSE, "This strategy is already active.");

        strategy.strategyState = StrategyState.OPEN;

        emit StrategyResumed(strategyAddress, strategy.name);
    }

    // - Dis aux stratégies de récupérer le yield
    function recoltYield(address strategyAddress) public onlyOwner {
        // P'tete ajouter une liste d'adresses plutôt pour tout récolter d'un coup, ou rien et ça récupère
        // une liste pré-enregistré des adresses (mais besoin d'un changement sur le mapping du haut).
        // Ou faire ça plutôt offchain avec les events.
        require(strategyAddress != address(0), "This strategy doesn't exist.");
        require(s_strategies[strategyAddress].isWhitelist, "This strategy is not on whitelist.");
        require(s_strategies[strategyAddress].strategyState == StrategyState.OPEN, "This strategy is not open.");
        IStrategy strategyInterface = IStrategy(strategyAddress);

        strategyInterface.recolt();

        emit YieldRecolted(strategyAddress, s_strategies[strategyAddress].name);
    }

    /// Get functions

    // - Récupérer la liste d'adresses de toutes les stratégies (Faire offchain avec les events ?)

    // - Récupérer la balance totale du protocole pour un token en particulier (hors stratégies ici)
    function getTokenBalance(address tokenAddress) public view returns (uint256) {
        ERC20 token = ERC20(tokenAddress);
        return token.balanceOf(address(this));
    }

    // - Récupérer la balance d'une stratégie en particulier (voir de toutes les stratégies en même temps si jamais)
    function getTokenBalanceStrategy(address tokenAddress, address strategyAddress) public view returns (uint256) {
        ERC20 token = ERC20(tokenAddress);
        return token.balanceOf(strategyAddress);
        // P'tete pas la meilleure façon de faire avec le yieldfarming.
        // P'tete avoir une getFunction() de la stratégie qui suit bien sa balance.
    }

    // - Récupérer la balance d'un utilisateur en particulier pour un token en particulier
    function getUserBalance(address userAddress, address tokenAddress) public view returns (uint256) {
        return s_totalBalances[userAddress][tokenAddress];
    }

    // - Récupérer l'adresse ou les noms des stratégies dans lesquelles est un utilisateur en particulier (Offchain avec les events ?)

    // - Récupérer la liste d'adresses de tous les utilisateurs du protocole (Offchain avec les events ?)

    // - Récupérer la liste d'adresses de tous les utilisateurs d'une stratégie (Offchain avec les events ?)

    // - Récupérer l'état d'une stratégie (OPEN | CLOSE)
    function getStrategyState(address strategyAddress) public view returns (StrategyState) {
        return s_strategies[strategyAddress].strategyState;
    }

    // - Récupérer le nom d'une stratégie à partir de son adresse
    function getStrategyName(address strategyAddress) public view returns (string memory) {
        return s_strategies[strategyAddress].name;
    }

    // - Vérifier si une stratégie est whitelist ou non
    function isStrategyWhitelist(address strategyAddress) public view returns (bool) {
        return s_strategies[strategyAddress].isWhitelist;
    }

    // - Récupérer l'adresse d'une stratégie à partir de son nom (Offchain avec les events ?)
}

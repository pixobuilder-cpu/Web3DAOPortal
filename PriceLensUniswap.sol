// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Interface officielle du QuoterV2 d'Uniswap V3 (Plus adapté aux appels de contrats et d'IA)
interface IQuoterV2 {
    struct QuoteExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint24 fee;
        uint160 sqrtPriceLimitX96;
    }

    function quoteExactInputSingle(QuoteExactInputSingleParams memory params)
        external
        view
        returns (
            uint256 amountOut,
            uint160 sqrtPriceX96After,
            uint32 initializedTicksCrossed,
            uint256 gasEstimate
        );

    function quoteExactInput(bytes calldata path, uint256 amountIn)
        external
        view
        returns (
            uint256 amountOut,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksCrossedList,
            uint256 gasEstimate
        );
}

contract PriceLensUniswap {
    // Adresse du QuoterV2 sur Polygon
    address private constant UNISWAP_V3_QUOTERV2 = 0x61FCe191b3384e5F761c4096c868228b59e6416c; 

    // Vos adresses sur Polygon
    address private constant BFT = 0x140098cCcdad0D8e63f8EF213cB3939e4d82d557;
    address private constant USDC = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359; // 6 décimales
    address private constant LINK = 0xb0897686c545045aFc77CF20eC7A532E3120E0F1; // 18 décimales

    uint24 public poolFee = 3000; // 0.3%

    // Structure propre pour envoyer toutes les données d'un coup à votre IA
    struct AIPriceReport {
        uint256 priceDirectUSDC;
        uint256 priceViaLINK;
        uint256 timestamp;
    }

    // Changement en "view" : utilisable sans payer de gaz par l'IA
    function obtenirPrixViaPoolUSDC() public view returns (uint256) {
        uint256 montantEntree = 10**18; // 1 BFT

        IQuoterV2.QuoteExactInputSingleParams memory params = IQuoterV2.QuoteExactInputSingleParams({
            tokenIn: BFT,
            tokenOut: USDC,
            amountIn: montantEntree,
            fee: poolFee,
            sqrtPriceLimitX96: 0
        });

        try IQuoterV2(UNISWAP_V3_QUOTERV2).quoteExactInputSingle(params) returns (uint256 amountOut, uint160, uint32, uint256) {
            return amountOut; 
        } catch {
            return 0; // Retourne 0 si la pool n'a pas assez de liquidité
        }
    }

    function obtenirPrixBFTversLINKversUSDC() public view returns (uint256) {
        uint256 montantEntree = 10**18; 
        bytes memory chemin = abi.encodePacked(BFT, poolFee, LINK, uint24(3000), USDC);

        try IQuoterV2(UNISWAP_V3_QUOTERV2).quoteExactInput(chemin, montantEntree) returns (uint256 amountOut, uint160[] memory, uint32[] memory, uint256) {
            return amountOut;
        } catch {
            return 0;
        }
    }

    /**
     * @notice La fonction "Lens" ultime pour votre IA
     * @dev Récupère toutes les routes de prix en un seul appel RPC
     */
    function getFullPriceReportForAI() external view returns (AIPriceReport memory) {
        return AIPriceReport({
            priceDirectUSDC: obtenirPrixViaPoolUSDC(),
            priceViaLINK: obtenirPrixBFTversLINKversUSDC(),
            timestamp: block.timestamp
        });
    }
}

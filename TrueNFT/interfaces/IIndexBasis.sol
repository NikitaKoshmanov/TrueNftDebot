pragma ton-solidity >=0.46.0;

interface IIndexBasis {
    function destruct() external;
    function getInfo() external view returns (
        address addrRoot,
        uint256 codeHashData
    );
}

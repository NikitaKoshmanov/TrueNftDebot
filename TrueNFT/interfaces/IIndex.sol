pragma ton-solidity >=0.46.0;

interface IIndex {
    function destruct() external;
    function getInfo() external view returns (
        address addrRoot,
        address addrOwner,
        address addrData
    );
}

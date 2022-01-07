pragma ton-solidity >= 0.43.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;
 
import "./Resourses/Debot.sol";
import "./Resourses/Terminal.sol";
import "./Resourses/Menu.sol";
import "./Resourses/AddressInput.sol";
import "./Resourses/ConfirmInput.sol";
import "./Resourses/Upgradable.sol";
import "./Resourses/Sdk.sol";
import "./Resourses/SigningBoxInput.sol";
import "./Resourses/AmountInput.sol";

// import "./Resourses//Msg.sol";
// import "./Resourses//NumberInput.sol";
// import "./Resourses//UserInfo.sol";

import "./TrueNFT/NftRoot.sol";
import "./TrueNFT/IndexBasis.sol";
import "./TrueNFT/Data.sol";
import "./TrueNFT/Index.sol";

enum ColorEnum{white, red, blue, green, lastEnum}

interface IMultisig {
    function sendTransaction(
        address dest,
        uint128 value,
        bool bounce,
        uint8 flags,
        TvmCell payload)
    external;
}

struct NftParams {
    string nftType;
}

contract NftDebot is Debot, Upgradable {

    address _tokenFutureAddress;
    address static _addrNFTRoot;
    address _addrMultisig;

    uint32 _keyHandle;

    Meta _nftParams;

    modifier accept {
        tvm.accept();
        _;
    }

    /// @notice Returns Metadata about DeBot.
    function getDebotInfo() public functionID(0xDEB) override view returns(
        string name, string version, string publisher, string key, string author,
        address support, string hello, string language, string dabi, bytes icon
    ) {
        name = "NFT DeBot";
        version = "0.1.0";
        publisher = "";
        key = "Nft minter";
        author = "";
        support = address.makeAddrStd(0, 0x66e01d6df5a8d7677d9ab2daf7f258f1e2a7fe73da5320300395f99e01dc3b5f);
        hello = "Hi, i'm a Minting-Nft DeBot.";
        language = "en";
        dabi = m_debotAbi.get();
        icon = "";
    }

    function getRequiredInterfaces() public view override returns (uint256[] interfaces) {
        return [ Terminal.ID, Menu.ID, AddressInput.ID, SigningBoxInput.ID, ConfirmInput.ID, AmountInput.ID ];
    }

    // initial setup
    function start() public override {
        Terminal.print(0, 'You need to attach future owner of the token.\nIt will be used also to pay for all transactions.');
        attachMultisig();
    }

    function setup1() public {
        uint[] none;
        SigningBoxInput.get(tvm.functionId(setKeyHandle), "Enter keys to sign all operations.", none);
    }

    function setup2() public {
        Terminal.print(0, 'You need to attach NftRoot, that will mint token.');
        attachNftRoot();

    }
    function menu() public {
        MenuItem[] _items;
        _items.push(MenuItem("Mint  Nft", "", tvm.functionId(deployNft)));
        _items.push(MenuItem("Change nftRoot address", "", tvm.functionId(attachNftRoot)));
        Menu.select("What to do?", "", _items);
    }


    function deployNft(uint32 index) public {
        index = index;
        Terminal.input(tvm.functionId(nftParamsSetType), "Enter NFT type: ", false);
        this.deployNftStep1();
    }

    function nftParamsSetType(string value) public {
        _nftParams.extra = value;
    }

    function deployNftStep1() public {
        Terminal.print(0, 'Let`s check data.');
        Terminal.print(0, format("Type: {}", _nftParams.extra));
        Terminal.print(0, format("Owner of Nft: {}\n", _addrMultisig));
        resolveNftDataAddr();
        ConfirmInput.get(tvm.functionId(deployNftStep2), "Sign and mint Token?");
    }

    function deployNftStep2(bool value) public {
        if(value) {
            Terminal.print(0, format('Your token will be deployed at address: {}', _tokenFutureAddress));
            this.deployNftStep3();
        } else {
            this.deployNft(0);
        }
    }

    function deployNftStep3() public accept {
        address[] emptyAddrs;
        uint256 hash = 123;
        TvmCell payload = tvm.encodeBody(
            NftRoot.mintNft,
            int8(0),
            bytes(''),
            bytes(''),
            uint256(hash),
            bytes(''),
            uint8(0),
            uint8(0),
            uint8(0),
            _nftParams 
        );
        optional(uint256) none;
        IMultisig(_addrMultisig).sendTransaction {
            abiVer: 2,
            extMsg: true,
            sign: true,
            pubkey: none,
            time: 0,
            expire: 0,
            callbackId: tvm.functionId(onNftDeploySuccess),
            onErrorId: tvm.functionId(onError),
            signBoxHandle: _keyHandle
        }(_addrNFTRoot, /*Fees.MIN_FOR_DATA_DEPLOY + Fees.CREATOR_MINTING_FEE +*/ 0.5 ton, true, 3, payload);
    }

    function onNftDeploySuccess() public accept {
        Terminal.print(0, format('Your token is deployed at address: {}', _tokenFutureAddress));
            Data(_tokenFutureAddress).getInfo{
                abiVer: 2,
                extMsg: true,
                callbackId: tvm.functionId(checkResult),
                onErrorId: tvm.functionId(onError),
                time: 0,
                expire: 0,
                sign: false
            }();
    }

    function checkResult(
        address addrRoot,
        address addrOwner,
        address addrAuthor,
        address addrData,
        uint256 id,
        bytes name,
        bytes url,
        uint8 number,
        uint8 amount,
        string nftType
    ) public {
        Terminal.print(0, 'Check actual data of deployed token: ');
        Terminal.print(0, format("Token address: {}", addrData));
        Terminal.print(0, format("Nft type: {}", nftType));
        Terminal.print(0, format("Root: {}", addrRoot));
        Terminal.print(0, format("Owner: {}", addrOwner));
        Terminal.print(0, format("Author: {}", addrAuthor));
        menu();
    }


    function resolveNftDataAddr() public accept{
        Data(_addrNFTRoot).getInfo{
            abiVer: 2,
            extMsg: true,
            callbackId: tvm.functionId(setNftAddr),
            onErrorId: 0,
            time: 0,
            expire: 0,
            sign: false
        }();
    }

    function setNftAddr(TvmCell code, uint totalMinted) public accept{
        TvmBuilder salt;
        salt.store(_addrNFTRoot);
        TvmCell codeData = tvm.setCodeSalt(code, salt.toCell());
        TvmCell stateNftData = tvm.buildStateInit({
            contr: Data,
            varInit: {_id: totalMinted},
            code: codeData
        });
        uint256 hashStateNftData = tvm.hash(stateNftData);
        _tokenFutureAddress = address.makeAddrStd(0, hashStateNftData);
    }


    function onError(uint32 sdkError, uint32 exitCode) public {
        Terminal.print(0, format("Sdk error {}. Exit code {}.", sdkError, exitCode));
        menu();
    }

    function attachMultisig() public accept {
        AddressInput.get(tvm.functionId(saveMultisig), "Enter address:");
    }

    function saveMultisig(address value) public accept {
        _addrMultisig = value;
        setup1();
    }
    
    function setKeyHandle(uint32 handle) public accept {
        _keyHandle = handle;
        menu();
    }
    
    function attachNftRoot() public accept {
        AddressInput.get(tvm.functionId(saveRootAddr), "Enter address:");
    }

    function saveRootAddr(address value) public accept {
        _addrNFTRoot = value;
        menu();
    }

    function onCodeUpgrade() internal override {
        tvm.resetStorage();
    }
}
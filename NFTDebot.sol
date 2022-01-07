pragma ton-solidity >=0.43.0;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "./Resourses/Debot.sol";
import "./Resourses/Terminal.sol";
import "./Resourses/SigningBoxInput.sol";
import "./Resourses/Menu.sol";
import "./Resourses/AmountInput.sol";
import "./Resourses/AddressInput.sol";
import "./Resourses/ConfirmInput.sol";
import "./Resourses/Upgradable.sol";
import "./Resourses/Sdk.sol";

import "./TrueNft/NftRoot.sol";
import "./TrueNft/Data.sol";
import './TrueNft/interfaces/IData.sol';

interface IMultisig {

    function sendTransaction(
        address dest,
        uint128 value,
        bool bounce,
        uint8 flags,
        TvmCell payload
    ) external;

}

struct NftMintParams {
    int8 wid;
    string name;
    string descriprion;
    uint256 contentHash;
    string mimeType;
    uint8 chunks;
    uint128 chunkSize;
    uint128 size;
    Meta meta;
}

contract NftDebot is Debot, Upgradable {

    address _addrNFT;
    address _addrNFTRoot;
    address _addrMultisig;

    uint32 _keyHandle;

    NftMintParams _nftParams;

    /// @notice Returns Metadata about DeBot.
    function getDebotInfo() public functionID(0xDEB) override view returns(
        string name, string version, string publisher, string key, string author,
        address support, string hello, string language, string dabi, bytes icon
    ) {
        name = "TrueNFT Debot";
        version = "1.0";
        publisher = "";
        key = "";
        author = "dadanikita";
        support = address(0);
        hello = "Hello, I am NFT Debot.";
        language = "en";
        dabi = m_debotAbi.get();
        icon = "";
    }

    function getRequiredInterfaces() public view override returns (uint256[] interfaces) {
        return [ Terminal.ID, Menu.ID, AddressInput.ID, SigningBoxInput.ID, ConfirmInput.ID, AmountInput.ID ];
    }

    function start() public override {
        mainMenu(0);
    }

    function mainMenu(uint32 index) public {
        if(_addrMultisig == address(0)) {
            Terminal.print(0, 'Looks like you do not have attached Multi-Signature Wallet.');
            attachMultisig();
        } else {
            restart();
        }
    }

    function attachMultisig() public {
        AddressInput.get(tvm.functionId(saveMultisig), "Enter Multi-Signature Wallet address: ");
    }

    function menu() public {
        uint[] none;
        SigningBoxInput.get(tvm.functionId(setKeyHandle), "Enter keys to sign all operations.", none);
        
    }

    function restart() public {
        if (_addrNFTRoot == address(0)) {
            attachNftRoot();
        } else {
            getCrystalWalletAddr(_addrNFTRoot);
        }
    }

    function getCrystalWalletAddr(address addr) public {
        Sdk.getAccountType(tvm.functionId(deployNft), addr);
	}

    function checkAccountStatus(int8 acc_type) public returns (bool) {
        if (acc_type == -1)  {
            return false;
        }
        if (acc_type == 0) {
            return false;
        }
        if (acc_type == 2) {
            return false;
        }
        return true;
    }

    function deployNft(int8 acc_type) public {
        MenuItem[] _items;
        if (!checkAccountStatus(acc_type)) {
            Terminal.print(0, format("NFT Root is not deployed!"));
        } else {
            _items.push(MenuItem("Mint NFT", "", tvm.functionId(nftParamsInput)));
        }
        Menu.select("Choose what you want to do", "", _items);
    }

    function nftParamsInput(uint32 index) public {
        tvm.accept();
        Terminal.input(tvm.functionId(nftParamsSetWid), "Enter NFT wid:", false);
        Terminal.input(tvm.functionId(nftParamsSetName), "Enter name:", false);

        this.deployNftStep1();
    }

    function nftParamsSetWid(int8 value) public { _nftParams.wid = value;}
    function nftParamsSetName(string value) public { _nftParams.name = value;}


    function deployNftStep1() public {
        Terminal.print(0, "NFT Data");
        Terminal.print(0, format("NFT owner: {}\n", _addrMultisig));
        Terminal.print(0, format("NFT wid: {}\n", _nftParams.wid));
        Terminal.print(0, format("Name: {}\n", _nftParams.name));
        /*DESCRIPTION*/
        //resolveNftDataAddr();
        ConfirmInput.get(tvm.functionId(deployNftStep2), "Sign and mint NFT?");
    }

    function deployNftStep2(bool value) public {
        if(value) {
            Terminal.print(0, format("Your token will be deployed at address: {}", _addrNFT));
            this.deployNftStep3();
        } else {
            this.deployNft(0);
        }
    }

    function deployNftStep3() public {
        optional(uint256) pubkey;

        TvmCell payload = tvm.encodeBody(
            NftRoot.mintNft,
            _nftParams.wid,
            _nftParams.name,
            _nftParams.descriprion,
            _nftParams.contentHash,
            _nftParams.mimeType,
            _nftParams.chunks,
            _nftParams.chunkSize,
            _nftParams.size,
            _nftParams.meta
        );
        IMultisig(_addrMultisig).sendTransaction {
            abiVer: 2,
            extMsg: true,
            sign: true,
            pubkey: pubkey,
            time: uint64(now),
            expire: 0,
            callbackId: tvm.functionId(onNftDeploySuccess),
            onErrorId: tvm.functionId(onNftDeployError),
            signBoxHandle: _keyHandle
        }(_addrNFTRoot, 2 ton, true, 3, payload);

    }
    
    function onNftDeploySuccess() public {
        tvm.accept();
        Terminal.print(0, format("Your token is deployed at address: {}", _addrNFT));
        Data(_addrNFT).getInfo{
            abiVer: 2,
            extMsg: true,
            callbackId: tvm.functionId(checkResult),
            onErrorId: tvm.functionId(onError),
            time: uint64(now),
            expire: 0,
            sign: false
        }();
    }

    function onNftDeployError(uint32 sdkError, uint32 exitCode) public {
        Terminal.print(0, format("Deploy failed: error {}, code {} ", sdkError, exitCode));
        restart();
    }

    function checkResult(
        address addrData,
        address addrRoot,
        address addrOwner,
        address addrTrusted,
        string rarityName,
        string url
    ) public {
        Terminal.print(0, "Data of deployed NFT: ");
        Terminal.print(0, format("NFT address: {}", addrData));
        Terminal.print(0, format("NFT owner: {}", addrOwner));
        Terminal.print(0, format("Rarity: {}\n", rarityName));
        Terminal.print(0, format("Link: {}\n", url));
        restart();
    }

    function onError(uint32 sdkError, uint32 exitCode) public {
        Terminal.print(0, format("Sdk error {}. Exit code {}.", sdkError, exitCode));
        restart();
    }

    // function getTokenData() public returns(TvmCell code, uint totalMinted) {
    //     tvm.accept();
    //     totalMinted = _totalSupply;
    //     code = _codeData;
    // }

    // function resolveNftDataAddr() public {
    //     tvm.accept();
    //     NftRoot(_addrNFTRoot).getTokenData{
    //         abiVer: 2,
    //         extMsg: true,
    //         callbackId: tvm.functionId(setNftAddr),
    //         onErrorId: tvm.functionId(onError),
    //         time: uint64(now),
    //         expire: 0,
    //         sign: false
    //     }();
    // }

    function setNftAddr(TvmCell code, uint totalMinted) public {
        tvm.accept();
        TvmBuilder salt;
        salt.store(_addrNFTRoot);
        TvmCell newCodeData = tvm.setCodeSalt(code, salt.toCell());
        TvmCell stateNftData = tvm.buildStateInit({
            contr: Data,
            varInit: {_id: totalMinted},
            code: newCodeData
        });
        uint256 hashStateNftData = tvm.hash(stateNftData);
        _addrNFT = address.makeAddrStd(0, hashStateNftData);
    }

    function attachNftRoot() public {
        AddressInput.get(tvm.functionId(saveRootAddr), "Attach NFTRoot.\n📋 Enter address:");
    }

    function saveMultisig(address value) public {
        tvm.accept();
        _addrMultisig = value;
        restart();
    }

    function saveRootAddr(address value) public {
        tvm.accept();
        if (_addrMultisig == value) {
            Terminal.print(tvm.functionId(attachNftRoot), "Address of NFTRoot must be vary from your wallet address!\n Try again.");
        } else {
            _addrNFTRoot = value;
            menu();
        }
    }

    function setKeyHandle(uint32 handle) public {
        tvm.accept();
        _keyHandle = handle;
        restart();
    }

    function onCodeUpgrade() internal override {
        tvm.resetStorage();
    }
    
}
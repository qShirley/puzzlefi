/* eslint-disable @typescript-eslint/no-explicit-any */
// Copyright (c) RoochNetwork
// SPDX-License-Identifier: Apache-2.0
// Author: Jason Jo

import {LoadingButton} from "@mui/lab";
import {Button, Chip, Drawer, Stack, Typography} from "@mui/material";
import {styled} from "@mui/material/styles";
import {Args, Transaction} from "@roochnetwork/rooch-sdk";
import {
    UseSignAndExecuteTransaction,
    useConnectWallet,
    useCreateSessionKey,
    useCurrentAddress,
    useCurrentSession,
    useRemoveSession,
    useRoochClientQuery,
    useWalletStore,
    useWallets,
} from "@roochnetwork/rooch-sdk-kit";
import {enqueueSnackbar} from "notistack";
import React, {useState} from "react";
import "./App.css";
import {shortAddress} from "./utils";
import {contractAddress, puzzlefiCoinModule, puzzleGameModule, roochGasCoinType} from "./constants.ts";
import {getIcon, getWinner} from "./hooks/utils.tsx";
import ButtonGroup from "@mui/material/ButtonGroup";
import ButtonGroup2, {ButtonGroup3} from "./components/ButtonGroup.tsx";
import PaidIcon from '@mui/icons-material/Paid';
import CurrencyExchangeIcon from '@mui/icons-material/CurrencyExchange';
import BookmarkIcon from '@mui/icons-material/Bookmark';
import InputButtonComponent from "./components/InputButton.tsx";
import CountUp from "react-countup";


const drawerWidth = 300;

const Main = styled("main", {shouldForwardProp: (prop) => prop !== "open"})<{
    open?: boolean;
}>(({theme, open}) => ({
    flexGrow: 1,
    alignItems: "center",
    padding: theme.spacing(3),
    transition: theme.transitions.create("margin", {
        easing: theme.transitions.easing.sharp,
        duration: theme.transitions.duration.leavingScreen,
    }),
    marginLeft: `${open ? drawerWidth : "0"}px`,
    ...(open && {
        transition: theme.transitions.create("margin", {
            easing: theme.transitions.easing.easeOut,
            duration: theme.transitions.duration.enteringScreen,
        }),
    }),
}));


function App() {
    const wallets = useWallets();
    const currentAddress = useCurrentAddress();
    const sessionKey = useCurrentSession();
    const connectionStatus = useWalletStore((state) => state.connectionStatus);
    const setWalletDisconnected = useWalletStore(
        (state) => state.setWalletDisconnected
    );
    const {mutateAsync: connectWallet} = useConnectWallet();

    const {mutateAsync: createSessionKey} = useCreateSessionKey();
    const {mutateAsync: removeSessionKey} = useRemoveSession();
    const {mutateAsync: signAndExecuteTransaction} =
        UseSignAndExecuteTransaction();

    const [showLeaderboard, setShowLeaderboard] = useState(false);
    const [betType, setBetType] = useState(1000);
    const [betAmount, setBetAmount] = useState(0);

    const {data: RoundResult, refetch: roundResultFetch} = useRoochClientQuery("executeViewFunction", {
        target: `${contractAddress}::${puzzleGameModule}::get_round_and_result`,
        typeArgs: [roochGasCoinType]
    })


    const {data: coins, refetch: coinsFetch} = useRoochClientQuery("executeViewFunction", {
        target: `0x3::account_coin_store::balance`,
        args: [Args.address(currentAddress?.genRoochAddress().toStr() || "")],
        typeArgs: [`${contractAddress}::${puzzlefiCoinModule}::PFC<${roochGasCoinType}>`]
    })

    const {data: BalanceResult, refetch} = useRoochClientQuery("getBalance", {
        owner: currentAddress?.genRoochAddress().toStr() || "",
        coinType: roochGasCoinType
    })

    const {data: PoolResult, refetch: PoolResultRefetch} = useRoochClientQuery("executeViewFunction", {
        target: `${contractAddress}::${puzzleGameModule}::get_coin_amount`,
        typeArgs: [roochGasCoinType]
    })


    const [sessionLoading, setSessionLoading] = useState(false);
    const [txnLoading, setTxnLoading] = useState(false);
    const handlerCreateSessionKey = async () => {
        if (sessionLoading) {
            return;
        }
        setSessionLoading(true);
        const defaultScopes = [`${contractAddress}::*::*`];
        createSessionKey(
            {
                appName: "puzzlefi",
                appUrl: "http://localhost:5173",
                maxInactiveInterval: 3600,
                scopes: defaultScopes,
            },
            {
                onSuccess: (result) => {
                    console.log("session key", result);
                },
                onError: (error) => {
                    if (String(error).includes("1004")) {
                        enqueueSnackbar("Insufficient gas, please claim gas first", {
                            variant: "warning",
                            action: (
                                <a
                                    href="https://rooch.network/build/getting-started/get-gas-coin"
                                    target="_blank"
                                >
                                    <Chip
                                        size="small"
                                        label="Get Rooch Testnet Coin"
                                        variant="filled"
                                        className="font-semibold !text-slate-50 min-h-10"
                                        sx={{
                                            background: "#000",
                                            borderRadius: "12px",
                                            cursor: "pointer",
                                        }}
                                    />
                                </a>
                            ),
                        });
                    } else {
                        enqueueSnackbar(String(error), {
                            variant: "warning",
                        });
                    }
                },
            }
        ).finally(() => setSessionLoading(false));
    };

    return (
        <Stack
            className="font-sans min-w-[1024px]"
            direction="column"
            sx={{
                minHeight: "calc(100vh - 4rem)",
            }}
        >
            <Stack justifyContent="space-between" className="w-full">
                <img src="./a.svg" width="160px" alt=""/>
                <Stack spacing={1} justifyItems="flex-end">
                    <ButtonGroup>
                        <Button
                            variant="outlined"
                            style={{backgroundColor: 'black', color: 'white'}}
                            onClick={async () => {
                                if (connectionStatus === "connected") {
                                    setWalletDisconnected();
                                    return;
                                }

                                await connectWallet({wallet: wallets[0]});
                            }}
                        >
                            {connectionStatus === "connected"
                                ? shortAddress(currentAddress?.toStr(), 8, 6) + " |" + (Number(BalanceResult?.balance) / (10 ** Number(BalanceResult?.decimals))).toFixed(2).toString() + BalanceResult?.symbol
                                : "Connect Wallet"}
                        </Button>

                    </ButtonGroup>
                    {sessionKey ? (
                        <Button
                            variant="contained"
                            // className="!mt-4"
                            onClick={() => {
                                console.log("-------------", sessionKey)
                                removeSessionKey({authKey: sessionKey.getAuthKey()});
                            }}
                        >
                            Clear Session
                        </Button>
                    ) : (
                        <LoadingButton
                            loading={sessionLoading}
                            variant="contained"
                            // className="!mt-4"
                            disabled={connectionStatus !== "connected"}
                            onClick={() => {
                                handlerCreateSessionKey();
                            }}
                        >
                            {connectionStatus !== "connected"
                                ? "No Session"
                                : "Create Session"}
                        </LoadingButton>
                    )}
                </Stack>

            </Stack>
            <Stack className="w-full" justifyContent="space-between">
                <Stack>
                    <Typography className="text-4xl font-semibold mt-6 text-left w-full mb-4">
                        Round :{" "}
                        {RoundResult && (
                            <span className="text-2xl">
                {RoundResult?.return_values?.[0].decoded_value.toString() || "N/A"}{" "}
                                <span
                                    className="text-xs ml-2">( Last Round Result: {getIcon(Number(RoundResult.return_values?.[1].decoded_value.toString()))}</span>
                  <span
                      className="text-xs ml-2"> Winner: {getWinner(RoundResult.return_values?.[2].decoded_value.toString() || "0x0000000000000000000000000000000000000000000000000000000000000001")})</span>
              </span>
                        )}
                    </Typography>
                </Stack>{" "}
            </Stack>
            <Stack
                className="mt-4 w-full font-medium "
                direction="column"
                alignItems="center"
            >
                <Drawer
                    sx={{
                        width: drawerWidth,
                        flexShrink: 0,
                        "& .MuiDrawer-paper": {
                            width: drawerWidth,
                            boxSizing: "border-box",
                            marginTop: "168px",
                            height: "calc(100% - 168px)",
                            background: "transparent",
                            p: 2,
                        },
                    }}
                    variant="persistent"
                    anchor="left"
                    open={showLeaderboard}
                >
                    <Typography className="text-xl font-semibold">
                        StakePool
                    </Typography>
                    <Stack>
                        <Typography fontSize={"small"} textAlign={"left"}>
                            <BookmarkIcon fontSize={"small"}></BookmarkIcon>
                            玩家的进行猜拳游戏的对手方为Stake Pool,玩家的胜负会改变池子中RGC数量
                        </Typography>
                    </Stack>
                    <Stack>
                        <Typography fontSize={"small"} textAlign={"left"}>
                            <BookmarkIcon fontSize={"small"}></BookmarkIcon>
                            将RGC质押到池子铸造PFC(PuzzleFi Coin),解质押PFC可以换回RGC,PFC的价值会随池子中RGC数量而改变,PFC等价于用户占池子的股份
                        </Typography>
                    </Stack>
                    <Stack className="mt-4 w-full font-medium ">
                        <Typography fontSize={"small"} textAlign={"left"}>
                            <PaidIcon></PaidIcon>
                            当前池子中RGC数量：
                            <CountUp
                                style={{
                                    fontVariantNumeric: "tabular-nums lining-nums",
                                    userSelect: "none",
                                    cursor: "pointer",
                                }}
                                preserveValue
                                duration={3}
                                separator=","
                                decimal="."
                                decimals={3}
                                end={(Number(Number(PoolResult?.return_values?.[0].decoded_value.toString()) / 10 ** 8)) || 0}
                            />
                            {" RGC"}
                        </Typography>
                    </Stack>
                    <Stack>
                        <Typography fontSize={"small"} textAlign={"left"}>
                            <PaidIcon></PaidIcon>
                            当前流通的PFC数量：
                            <CountUp
                                style={{
                                    fontVariantNumeric: "tabular-nums lining-nums",
                                    userSelect: "none",
                                    cursor: "pointer",
                                }}
                                preserveValue
                                duration={3}
                                separator=","
                                decimal="."
                                decimals={3}
                                end={(Number(Number(PoolResult?.return_values?.[1].decoded_value.toString()) / 10 ** 8)) || 0}
                            />
                            {" PFC"}
                        </Typography>
                    </Stack>
                    <Stack className="mt-4 w-full font-medium ">
                        <Typography fontSize={"small"} textAlign={"left"}>
                            <CurrencyExchangeIcon></CurrencyExchangeIcon>
                            您拥有的PFC数量:
                            <CountUp
                                style={{
                                    fontVariantNumeric: "tabular-nums lining-nums",
                                    userSelect: "none",
                                    cursor: "pointer",
                                }}
                                preserveValue
                                duration={3}
                                separator=","
                                decimal="."
                                decimals={3}
                                end={(Number(Number(coins?.return_values?.[0].decoded_value.toString()) / 10 ** 8)) || 0}
                            />
                            {" PFC"}
                        </Typography>
                    </Stack>
                    <Stack className="mt-4 w-full font-medium ">
                        <Typography fontSize={"small"} textAlign={"left"}>


                            <CurrencyExchangeIcon></CurrencyExchangeIcon>
                            您拥有的RGC数量:
                            <CountUp
                                style={{
                                    fontVariantNumeric: "tabular-nums lining-nums",
                                    userSelect: "none",
                                    cursor: "pointer",
                                }}
                                preserveValue
                                duration={3}
                                decimalPlaces={2.1}
                                separator=","
                                decimal="."
                                decimals={3}
                                end={(Number(BalanceResult?.balance) / (10 ** Number(BalanceResult?.decimals))) || 0}
                            />
                            {" RGC"}
                        </Typography>
                    </Stack>
                    <Stack className="mt-4 w-full font-medium ">
                        <InputButtonComponent maxLength={Number(BalanceResult?.balance)} name={"Stake RGC"}
                                              text={`1RGC ≈ ${(((10 ** 8 + Number(PoolResult?.return_values?.[0].decoded_value.toString())) * Number(PoolResult?.return_values?.[1].decoded_value.toString()) / Number(PoolResult?.return_values?.[0].decoded_value.toString()) - Number(PoolResult?.return_values?.[1].decoded_value.toString())) / (10 ** 8)).toFixed(4)}PFC`}
                                              onSelectionChange={
                                                  async (value) => {
                                                      if (!sessionKey) {
                                                          return;
                                                      }
                                                      try {
                                                          setTxnLoading(true);
                                                          const txn = new Transaction();
                                                          txn.callFunction({
                                                              address: contractAddress,
                                                              module: puzzleGameModule,
                                                              function: "stake",
                                                              args: [
                                                                  // amount
                                                                  Args.u256(BigInt(value)),
                                                              ],
                                                              typeArgs: [roochGasCoinType]
                                                          });
                                                          const res = await signAndExecuteTransaction({transaction: txn});
                                                          if (res.execution_info.status.type === "executed") {
                                                              enqueueSnackbar("stake success", {
                                                                  variant: "success",
                                                                  anchorOrigin: {
                                                                      vertical: 'bottom',
                                                                      horizontal: 'right',
                                                                  }
                                                              });
                                                          } else if (res.execution_info.status.type === "moveabort") {
                                                              enqueueSnackbar("stake Failed", {
                                                                  variant: "warning",
                                                                  anchorOrigin: {
                                                                      vertical: 'bottom',
                                                                      horizontal: 'right',
                                                                  }
                                                              })
                                                          }
                                                          await Promise.all([refetch(), roundResultFetch(), PoolResultRefetch(), coinsFetch()]);
                                                      } catch (error) {
                                                          console.error(String(error));
                                                      } finally {
                                                          setTxnLoading(false);
                                                      }
                                                  }
                                              }></InputButtonComponent>
                    </Stack>

                    <Stack className="mt-4 w-full font-medium ">
                        <InputButtonComponent maxLength={Number(coins?.return_values?.[0].decoded_value.toString())}
                                              name={"Redeem"}
                                              text={`1PFC ≈ ${((Number(PoolResult?.return_values?.[0].decoded_value.toString()) - (Number(PoolResult?.return_values?.[0].decoded_value.toString()) * (Number(PoolResult?.return_values?.[1].decoded_value.toString()) - (10 ** 8))) / (Number(PoolResult?.return_values?.[1].decoded_value.toString()))) / (10 ** 8)).toFixed(4)}RGC`}
                                              onSelectionChange={
                                                  async (value) => {
                                                      if (!sessionKey) {
                                                          return;
                                                      }
                                                      try {
                                                          setTxnLoading(true);
                                                          const txn = new Transaction();
                                                          txn.callFunction({
                                                              address: contractAddress,
                                                              module: puzzleGameModule,
                                                              function: "redeem",
                                                              args: [
                                                                  // amount
                                                                  Args.u256(BigInt(value)),
                                                              ],
                                                              typeArgs: [roochGasCoinType]
                                                          });
                                                          const res = await signAndExecuteTransaction({transaction: txn});
                                                          if (res.execution_info.status.type === "executed") {
                                                              enqueueSnackbar("redeem success", {
                                                                  variant: "success",
                                                                  anchorOrigin: {
                                                                      vertical: 'bottom',
                                                                      horizontal: 'right',
                                                                  }
                                                              });
                                                          } else if (res.execution_info.status.type === "moveabort") {
                                                              enqueueSnackbar("redeem Failed", {
                                                                  variant: "warning",
                                                                  anchorOrigin: {
                                                                      vertical: 'bottom',
                                                                      horizontal: 'right',
                                                                  }
                                                              })
                                                          }
                                                          await Promise.all([refetch(), roundResultFetch(), PoolResultRefetch(), coinsFetch()]);
                                                      } catch (error) {
                                                          console.error(String(error));
                                                      } finally {
                                                          setTxnLoading(false);
                                                      }
                                                  }
                                              }></InputButtonComponent>
                    </Stack>
                </Drawer>
                <Main open={showLeaderboard}>
                    <Stack
                        spacing={1}
                        className="text-xl w-full text-center items-center justify-center"
                    >
                        <Typography>石头剪刀布</Typography>
                    </Stack>
                    <Stack>
                        <Typography fontSize={"small"}>
                            - 玩家可以通过押注竞猜或质押到StakePool参与游戏赢取 Rooch Gas Coin
                        </Typography>
                    </Stack>
                    <Stack fontSize={"small"}>
                        - ✊：系统出现概率为3/10,获胜赔率为1:1,平局退回押注的金额（✊只能胜过 ✌️)
                    </Stack>
                    <Stack fontSize={"small"}>
                        - ✌️：系统出现概率为3/10,获胜赔率为1:1,平局退回押注的金额（✌️只能胜过 🖐️)
                    </Stack>
                    <Stack fontSize={"small"}>
                        - 🖐：系统出现概率为3/10,获胜赔率为1:1,平局退回押注的金额（🖐只能胜过 ✊)
                    </Stack>
                    <Stack fontSize={"small"}>
                        - 🌟：系统出现概率为1/10,获胜赔率为1:8,只有压中才胜利
                    </Stack>
                    <Button
                        className="!mt-4"
                        onClick={async () => {
                            setShowLeaderboard(!showLeaderboard);
                            await Promise.all([refetch(), roundResultFetch(), PoolResultRefetch(), coinsFetch()]);
                        }}
                        variant="outlined"
                    >
                        Stake Pool
                    </Button>

                    <Typography className="!mt-4">
                    </Typography>

                    <ButtonGroup3 onSelectionChange={setBetType}></ButtonGroup3>
                    <Typography className="tracking-wide font-black !mt-4">
                    </Typography>

                    <ButtonGroup2 onSelectionChange={setBetAmount}></ButtonGroup2>
                    <Typography className="tracking-wide font-black !mt-4">
                    </Typography>
                    <Stack>
                        <Typography className={"mt-4"}></Typography>
                    </Stack>
                    <LoadingButton
                        loading={txnLoading}
                        variant="contained"
                        sx={{
                            fontWeight: 'bold',
                            fontFamily: '"Raleway", sans-serif', // 使用游戏风格字体
                            fontSize: sessionKey? '35px': '22px',
                            transition: 'transform 0.3s ease, background-color 0.3s ease, border 0.3s ease',
                            '&:hover, &:active': {
                                transform: 'scale(1.25)', // 放大按钮
                                // fontSize: '28px',

                                // border: selectedButton === value ? '2px solid darkblue' : '2px solid darkblue',
                            }
                        }
                        }
                        className="w-32"
                        // fullWidth
                        disabled={(!sessionKey || betAmount === 0 || betType === 1000)}
                        onClick={async () => {
                            console.log("bet:", betType, betAmount)
                            if (Number(BalanceResult?.balance) < betAmount) {
                                enqueueSnackbar("Insufficient RGC, please claim gas first", {
                                    variant: "warning",
                                    anchorOrigin: {
                                        vertical: 'bottom',
                                        horizontal: 'right',
                                    }
                                });
                            } else {
                                try {
                                    setTxnLoading(true);
                                    const txn = new Transaction();
                                    txn.callFunction({
                                        address: contractAddress,
                                        module: puzzleGameModule,
                                        function: "new_finger_game",
                                        args: [
                                            // player_guessing
                                            Args.u64(BigInt(betType)),
                                            // bet_amount
                                            Args.u256(BigInt(betAmount)),
                                        ],
                                        typeArgs: [roochGasCoinType]
                                    });
                                    const result = await signAndExecuteTransaction({transaction: txn});
                                    if (result.execution_info.status.type === "moveabort") {
                                        enqueueSnackbar("Play New Game Failed", {
                                            variant: "warning",
                                            anchorOrigin: {
                                                vertical: 'bottom',
                                                horizontal: 'right',
                                            }
                                        });
                                        if (result.execution_info.status.abort_code == "4") {
                                            enqueueSnackbar("StakePool RGC Insufficient, Please Contact the Admin", {
                                                variant: "error",
                                                anchorOrigin: {
                                                    vertical: 'bottom',
                                                    horizontal: 'right',
                                                }
                                            });
                                        }
                                    } else if (result.execution_info.status.type === "executed") {
                                        console.log(result)
                                        enqueueSnackbar("Play success, wait result", {
                                            variant: "success",
                                            anchorOrigin: {
                                                vertical: 'bottom',
                                                horizontal: 'right',
                                            }
                                        });
                                    }
                                    await Promise.all([refetch(), roundResultFetch(), PoolResultRefetch()]);
                                } catch (error) {
                                    console.error(String(error));
                                    if (String(error).includes("1004")) {
                                        enqueueSnackbar("Insufficient gas, please claim gas first", {
                                            variant: "warning",
                                            anchorOrigin: {
                                                vertical: 'bottom',
                                                horizontal: 'right',
                                            }
                                        });
                                    } else {
                                        enqueueSnackbar(String(error), {
                                            variant: "warning",
                                            anchorOrigin: {
                                                vertical: 'bottom',
                                                horizontal: 'right',
                                            }
                                        });
                                    }
                                } finally {
                                    setTxnLoading(false);
                                }
                            }
                        }}
                    >
                        {sessionKey ? "Play" : "Please create Session Key first"}
                    </LoadingButton>
                </Main>
            </Stack>
        </Stack>
    );
}

export default App;

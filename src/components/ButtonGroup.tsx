import React, { useState } from 'react';
import {Button, Stack} from '@mui/material';

type ButtonGroupProps = {
    onSelectionChange?: (value: number) => void; // 显式指定类型
};

const ButtonGroup2: React.FC<ButtonGroupProps> = ({onSelectionChange}) => {
    const [selectedButton, setSelectedButton] = useState(0);

    const handleClick = (value: number) => {
        setSelectedButton(value);
        if (onSelectionChange) {
            onSelectionChange(value);  // 回调选中的按钮值
        }
    };

    const buttonStyle = (value: number) => ({
        backgroundColor: selectedButton === value ? '#FF8D65' : '#5597FF', // 选中时颜色变深
        color: 'white',
        fontFamily: '"Gill Sans", sans-serif',
        fontWeight: 'bold',
        width: '100px',
        height: '45px',
        position: 'relative', // 保持按钮相对定位
        transition: 'transform 0.3s ease, background-color 0.3s ease, border 0.3s ease',
        '&:hover, &:active': {
            // border: '2px solid darkblue', // 鼠标悬停时改变边框颜色
            backgroundColor: selectedButton === value ? '#FF8D65' : '#5597FF',
            transform: 'scale(1.25)',

        },
    });

    return (
        <Stack spacing={1.5} direction="column">
            <Stack spacing={2} direction="row">
                <Button
                    variant="contained"
                    size="large"
                    sx={buttonStyle(10 ** 8)}
                    onClick={() => handleClick(10 ** 8)}
                >
                    1RGC
                </Button>
                <Button
                    variant="contained"
                    size="large"
                    sx={buttonStyle(10 ** 8 * 2)}
                    onClick={() => handleClick(10 ** 8 * 2)}
                >
                    2RGC
                </Button>
                <Button
                    variant="contained"
                    size="large"
                    sx={buttonStyle(10 ** 8 * 5)}
                    onClick={() => handleClick(10 ** 8 * 5)}
                >
                    5RGC
                </Button>
            </Stack>
            <Stack spacing={2} direction="row">
                <Button
                    variant="contained"
                    size="large"
                    sx={buttonStyle(10 * 10 ** 8)}
                    onClick={() => handleClick(10 * 10 ** 8)}
                >
                    10RGC
                </Button>
                <Button
                    variant="contained"
                    size="large"
                    sx={buttonStyle( 10 ** 8 * 20)}
                    onClick={() => handleClick(10 ** 8 * 20)}
                >
                    20RGC
                </Button>
                <Button
                    variant="contained"
                    size="large"
                    sx={buttonStyle(10 ** 8 * 50)}
                    onClick={() => handleClick(10 ** 8 * 50)}
                >
                    50RGC
                </Button>
            </Stack>
        </Stack>
    );
};

export const ButtonGroup3: React.FC<ButtonGroupProps> = ({onSelectionChange}) => {
    const [selectedButton, setSelectedButton] = useState(1000);

    const handleClick = (value: number) => {
        setSelectedButton(value);
        if (onSelectionChange) {
            onSelectionChange(value);  // 回调选中的按钮值
        }
    };

    const buttonStyle = (value: number) => ({
        backgroundColor: selectedButton === value ? '#FFC299' : '#87CEFA',
        color: 'white',
        fontFamily: '"Gill Sans", sans-serif',
        fontWeight: 'bold',
        width: '100px',
        height: '45px',
        fontSize: '22px',
        position: 'relative', // 保持按钮相对定位
        transition: 'transform 0.3s ease, background-color 0.3s ease, border 0.3s ease',
        '&:hover, &:active': {
            transform: 'scale(1.25)', // 放大按钮
            fontSize: '28px',
            // border: selectedButton === value ? '2px solid darkblue' : '2px solid darkblue',
            backgroundColor: selectedButton === value ? '#FFC299' : '#87CEFA',
        },
    });


    return (

        <Stack spacing={1.5} direction="column">
            <Stack spacing={3} direction="row">
                <Button
                    variant="contained"
                    size="large"
                    sx={buttonStyle(1)}
                    onClick={() => handleClick(1)}
                >
                    ✊
                </Button>
                <Button
                    variant="contained"
                    size="large"
                    sx={buttonStyle(4)}
                    onClick={() => handleClick(4)}
                >
                    ✌️
                </Button>
            </Stack>
            <Stack spacing={3} direction="row">
                <Button
                    variant="contained"
                    size="large"
                    sx={buttonStyle(7)}
                    onClick={() => handleClick(7)}
                >
                    🖐
                </Button>
                <Button
                    variant="contained"
                    size="large"
                    sx={buttonStyle( 0)}
                    onClick={() => handleClick(0)}
                >
                    🌟
                </Button>
            </Stack>
        </Stack>
    );
};

export default ButtonGroup2;


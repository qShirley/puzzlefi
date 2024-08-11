import React, { useState } from 'react';
import {Button, TextField, Typography, Box, Stack} from '@mui/material';

interface InputButtonComponentProps {
    maxLength: number;
    name: string;
    onSelectionChange?: (value: number) => void;
    text: string;
}


const InputButtonComponent: React.FC<InputButtonComponentProps> = ({ maxLength, name, onSelectionChange,text }) => {
    const [inputValue, setInputValue] = useState('');
    const [showWarning, setShowWarning] = useState(false);

    const handleInputChange = (event: React.ChangeEvent<HTMLInputElement>) => {
        const value = event.target.value;
        const numericValue = parseFloat(value) * 10**8;

        setInputValue(value);
        if (!isNaN(Number(value))) {
            setShowWarning(numericValue > maxLength);
        } else {
            setShowWarning(true); // 处理非数值输入的情况
        }
    };

    const handleConfirmClick = () => {
        const numericValue = parseFloat(inputValue);
        if (!inputValue || showWarning) {
            return;
        }
        if (onSelectionChange) {
            onSelectionChange(10 ** 8 * numericValue);  // 回调选中的按钮值
        }
        console.log('Confirmed:', inputValue);
    };


    return (
        <Box>
            <TextField
                label={text}
                variant="outlined"
                value={inputValue}
                onChange={handleInputChange}
            />
            {showWarning && (
                <Typography color="error" variant="body2">
                    输入值无效或超过了您的token数量 ({maxLength/10**8})！
                </Typography>
            )}
            <Stack></Stack>
            <Typography className={"mt-4"}></Typography>
            <Button
                variant="contained"
                color={inputValue && !showWarning ? 'primary' : 'secondary'}
                onClick={handleConfirmClick}
                disabled={!inputValue || showWarning}
                sx={{
                    backgroundColor: !inputValue || showWarning ? 'grey' : undefined,
                }}
            >
                {name}
            </Button>
        </Box>
    );
};

export default InputButtonComponent;

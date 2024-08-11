import {shortAddress} from "../utils.ts";


export const getIcon = (value: number) => {
  if (value == 0) {
    return '🌟'
  }else if(value >= 1 && value <= 3) {
    return '✊';
  } else if (value >= 4 && value <= 6) {
    return '✌️';
  } else if (value >= 7 && value <= 9) {
    return '🖐';
  } else {
    return 'N/A';
  }
};

export const getWinner = (value: string) => {
  if (value === "0x0000000000000000000000000000000000000000000000000000000000000001") {
    return 'N/A'
  }else if(value === "0x0000000000000000000000000000000000000000000000000000000000000003") {
    return 'Tie';
  } else if (value === "0x0000000000000000000000000000000000000000000000000000000000000000") {
    return 'Puzzlefi';
  } else {

    return shortAddress(value, 8, 6);
  }
};


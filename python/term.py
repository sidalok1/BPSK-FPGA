#!/usr/bin/env python3
import argparse
import serial
import serial.threaded
from blessed import Terminal
from enum import StrEnum, auto
from threading import Lock


parser = argparse.ArgumentParser(
    prog        = "term.py",
    description = "Communicate with MicroBlaze software on programmed FPGA",
    epilog      = "Defaults should reflect hardware configuration, but may need to be changed"
)

parser.add_argument(
    "port",
    type        = ascii,
    help        = "Port to connect to (e.g. '/dev/ttyUSB0' or 'COM3')"
)

parser.add_argument(
    "-b", "--baud",
    type        = int,
    default     = 115200,
    help        = "Baud rate of the UART connection (default: %(default)s)"
)

parser.add_argument(
    "-d", "--data_bits",
    type        = int,
    default     = serial.EIGHTBITS,
    choices     = [serial.FIVEBITS, serial.SIXBITS, serial.SEVENBITS, serial.EIGHTBITS],
    help        = "Number of data bits in frame (default: %(default)s)"
)

parser.add_argument(
    "-s", "--stop_bits",
    type        = int,
    default     = serial.STOPBITS_ONE,
    choices     = [serial.STOPBITS_ONE, serial.STOPBITS_TWO],
    help        = "Number of stop bits (default: %(default)s)"
)

parser.add_argument(
    "-p", "--parity",
    default     = serial.PARITY_NONE,
    choices     = [serial.PARITY_NONE, serial.PARITY_ODD, serial.PARITY_EVEN],
    help        = "Parity bit to use (defaults to none)"
)

parser.add_argument(
    "--history_len",
    type        = int,
    default     = 50,
    help        = "Number of "
)

class Direction(StrEnum):
    IN = f"{Terminal().seagreen2}"
    OUT = f"{Terminal().turquoise}"
    TERM = f"{Terminal().gold}"

type msg = tuple[Direction, str]

received_messages: list[msg] = list()

# class TermApp(serial.threading.LineReader)
class TermApp():   
    def __init__(self):
        self.terminal_input: str = str()
        self.serial_output: str = str()
        # self.lock = Lock()
        self.term = Terminal()
        self.hist_len = 50
        # self.buffer = bytearray()
        # self.transport = None

    
    def push(self, message: msg):
        global received_messages
        if len(received_messages) >= self.hist_len:
            received_messages.pop()
        received_messages.insert(0, message)

    # def handle_line(self, data):
    #     with self.lock:
    #         self.push((Direction.TERM, "Message received from radio"))
    #         self.push((Direction.OUT, str(data)))

    # def connection_made(self, transport):
    #     super(TermApp, self).connection_made(transport)
    #     with self.lock:
    #         self.push((Direction.TERM, "Serial connection established."))

    # def connection_lost(self, exc):
    #     with self.lock:
    #         self.push((Direction.TERM, "Serial connection lost."))
    #         if exc:
    #             self.push((Direction.TERM, str(exc)))

    def render(self):
        global received_messages
        # with self.lock, self.term.synchronized_output(), self.term.location(0, self.term.height - 1):
        with self.term.synchronized_output(), self.term.location(0, self.term.height - 1):
            # print(self.term.clear())
            line_list = self.term.wrap(self.terminal_input)
            if len(line_list) == 0:
                line_list = [""]
            print(
                self.term.move_up(len(line_list)) + 
                '\n'.join(line_list) +
                self.term.clear_eos() +
                self.term.move_up(len(line_list) + 1) + 
                self.term.move_x(0)
            )
            print(self.term.gray('-' * self.term.width) + self.term.move_up(1) + self.term.move_x(0))
            for direction, text in received_messages:
                _, y = self.term.get_location()
                line_list = self.term.wrap(text)
                tlen = len(line_list)
                if y < 0:
                    break
                elif y < tlen - 1:
                    print(
                        str(direction) +
                        self.term.move_up(tlen - y - 1) +
                        '\n'.join(line_list[-(tlen - y - 1):]) +
                        self.term.clear_eol() +
                        self.term.move_up(tlen) +
                        self.term.move_x(0)
                    )
                else:
                    print(
                        str(direction) +
                        self.term.move_up(tlen - 1) +
                        '\n'.join(line_list) +
                        self.term.clear_eol() +
                        self.term.move_up(tlen) +
                        self.term.move_x(0)
                    )



if __name__=='__main__':
    args = parser.parse_args()
    s = serial.Serial(args.port.strip("'"), args.baud, args.data_bits, args.parity, args.stop_bits, timeout=(1/60))
    connection = TermApp()
    with connection.term.cbreak(), connection.term.fullscreen(), connection.term.hidden_cursor():
        while True:
            key = connection.term.inkey(timeout=(1/60))
            match key.name:
                case 'KEY_ENTER':
                    if len(connection.terminal_input) != 0:
                        s.write((connection.terminal_input + '\n').encode(errors="ignore"))
                        connection.push((Direction.IN, str(connection.terminal_input)))
                        connection.terminal_input = str()
                case 'KEY_ESCAPE':
                    break
                case 'KEY_BACKSPACE':
                    if len(connection.terminal_input) > 0:
                        connection.terminal_input = connection.terminal_input[:-1]
                case None:
                    if len(connection.terminal_input) < 15:
                        connection.terminal_input += key
                case _:
                    pass
            byte = s.read()
            connection.serial_output += byte.decode(errors="ignore")
            if byte == b'\n':
                connection.push((Direction.OUT, connection.serial_output))
                connection.serial_output = str()
            connection.render()
    # with serial.threaded.ReaderThread(s, TermApp) as connection, connection.term.cbreak(), connection.term.fullscreen(), connection.term.hidden_cursor():
    #     while True:
    #         key = connection.term.inkey(timeout=(1/60))
    #         with connection.lock:
    #             match key.name:
    #                 case 'KEY_ENTER':
    #                     if len(connection.terminal_input) != 0:
    #                         connection.write_line(connection.terminal_input)
    #                         connection.push((Direction.IN, str(connection.terminal_input)))
    #                         connection.terminal_input = str()
    #                 case 'KEY_ESCAPE':
    #                     break
    #                 case 'KEY_BACKSPACE':
    #                     if len(connection.terminal_input) > 0:
    #                         connection.terminal_input = connection.terminal_input[:-1]
    #                 case None:
    #                     if len(connection.terminal_input) < 15:
    #                         connection.terminal_input += key
    #                 case _:
    #                     pass
    #         connection.render()
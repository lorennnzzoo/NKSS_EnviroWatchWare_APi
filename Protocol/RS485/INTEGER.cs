using Models;
using Protocol.Interfaces;
using System;
using System.Collections.Generic;
using System.IO.Ports;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace Protocol.RS485
{
    public class INTEGER : IProtocol
    {
        public string ByteArrayToHexString(byte[] data)
        {
            StringBuilder sb = new StringBuilder(data.Length * 3);
            try
            {

                foreach (byte b in data)
                    sb.Append(Convert.ToString(b, 16).PadLeft(2, '0').PadRight(3, ' '));

            }
            catch (Exception ex)
            {
                //NKSS.Business.Log.Error("Error converting Binary to Hex", StationDetails.StationName, ChannelData.ChannelName, ex);
            }
            return sb.ToString().ToUpper();
        }

        public string ConnectToModuleAndGetResponse(Analyzer analyzer)
        {
            string response = string.Empty; //intitially response as empty;
            if (analyzer.CommunicationType.ToUpper() == "C")//if type is C comport method gets called.
            {
                response = SerialPortWriteAndReceiveResponse(analyzer.Command, analyzer.ComPort, (int)analyzer.BaudRate);
            }
            else if (analyzer.CommunicationType.ToUpper() == "IP")//if type is iP TCP/Ip method gets called.
            {
                response = TCP_IPWriteAndReceiveResponse(analyzer.ComPort, analyzer.IpAddress, analyzer.Port.ToString());
            }
            else
            {
                response = UDP_IPWriteAndReceiveResponse(analyzer.ComPort, analyzer.IpAddress, analyzer.Port.ToString());
            }
            return response;
        }

        public decimal? GetDataFromResponse(string response,Channel channel)
        {
            decimal? value = null;
            value = ProcessResponseString(response, channel);
            return value;
        }

        public byte[] HexStringToByteArray(string s)
        {
            byte[] buffer = new byte[s.Length / 2];
            try
            {
                s = s.Replace(" ", "");

                for (int i = 0; i < s.Length; i += 2)
                    buffer[i / 2] = Convert.ToByte(s.Substring(i, 2), 16);

            }
            catch (Exception ex)
            {
                //NKSS.Business.Log.Error("Error converting Hex to Binary", StationDetails.StationName, ChannelData.ChannelName, ex);
            }
            return buffer;
        }

        public decimal? ProcessResponseString(string response, Channel channel)
        {
            decimal? value = null;
            try
            {
                string[] outputarry = response.Split(' ');

                string combinedValue = outputarry[(int)channel.ValuePosition] + outputarry[(int)channel.ValuePosition + 1];
                decimal decValue = Convert.ToInt32(combinedValue, 16);
                value = Convert.ToDecimal(decValue);
            }
            catch (Exception ex)
            {
                //
            }
            return value;//return the value.
        }

        public string SerialPortWriteAndReceiveResponse(string command, string comport, int baudrate)
        {
            string response = string.Empty;//intitializing empty response string.
            using (SerialPort serialPort = new SerialPort(comport, baudrate, Parity.None, 8, StopBits.One))//creating serialport instance.
            {
                try
                {
                    if (!serialPort.IsOpen)
                    {
                        serialPort.Open();
                    }
                    byte[] dataToSend = HexStringToByteArray(command);//converting the hex string to byte array before writing to comport
                    serialPort.Write(dataToSend, 0, dataToSend.Length);//writing byte array to comport                    
                    //NKSS.Business.Log.Information("Sent Command", StationDetails.StationName, ChannelData.ChannelName);
                    serialPort.ReadTimeout = 5000;
                    byte[] buffer = new byte[1024];//creating butffer byte array to store response
                    Thread.Sleep(5000);//this sleeping time used to get the complete response instead of getting first byte and returning it. cause the program runs fast it returns the first received byte
                    int bytesRead = serialPort.Read(buffer, 0, buffer.Length);//read and store the byte array in buffer.
                    response = BitConverter.ToString(buffer, 0, bytesRead).Replace("-", " ");//convert the buffer to actual string.
                }
                catch (Exception ex)
                {

                    //NKSS.Business.Log.Error("Error at ConnectToModuleAndGetResponse COMPORT", StationDetails.StationName, ChannelData.ChannelName, ex);
                }
                finally
                {
                    if (serialPort.IsOpen)
                    {
                        serialPort.Close();
                    }
                }
            }
            return response;//return the response
        }

        public string TCP_IPWriteAndReceiveResponse(string command, string ip, string comport)
        {
            throw new NotImplementedException();
        }

        public string UDP_IPWriteAndReceiveResponse(string command, string ip, string comport)
        {
            throw new NotImplementedException();
        }
    }
}

using log4net;
using log4net.Config;
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
        private static readonly ILog logger = LogManager.GetLogger(typeof(INTEGER));
        public INTEGER()
        {
            XmlConfigurator.Configure(new System.IO.FileInfo("log4net.config"));
        }
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
                logger.Error($"Error at ByteArrayToHexString", ex);
            }
            return sb.ToString().ToUpper();
        }

        public string ConnectToModuleAndGetResponse(Analyzer analyzer)
        {
            logger.Info($"Connecting to module");
            string response = string.Empty; //intitially response as empty;
            if (analyzer.CommunicationType.ToUpper() == "C")//if type is C comport method gets called.
            {
                logger.Info($"Communication Type : {analyzer.CommunicationType.ToUpper()}");
                response = SerialPortWriteAndReceiveResponse(analyzer.Command, analyzer.ComPort, (int)analyzer.BaudRate);
            }
            else if (analyzer.CommunicationType.ToUpper() == "IP")//if type is iP TCP/Ip method gets called.
            {
                logger.Info($"Communication Type : {analyzer.CommunicationType.ToUpper()}");
                response = TCP_IPWriteAndReceiveResponse(analyzer.ComPort, analyzer.IpAddress, analyzer.Port.ToString());
            }
            else if(analyzer.CommunicationType.ToUpper()=="UDP")
            {
                logger.Info($"Communication Type : {analyzer.CommunicationType.ToUpper()}");
                response = UDP_IPWriteAndReceiveResponse(analyzer.ComPort, analyzer.IpAddress, analyzer.Port.ToString());
            }
            else
            {
                logger.Warn($"Invalid Communication Type : {analyzer.CommunicationType.ToUpper()}");
            }
            return response;
        }

        public decimal? GetDataFromResponse(string response,Channel channel)
        {
            logger.Info($"Processing response");
            decimal? value = null;
            value = ProcessResponseString(response, channel);
            logger.Info($"Received value after processing : {value}");
            return value;
        }

        public byte[] HexStringToByteArray(string s)
        {
            logger.Info($"Converstion from Hex to Byte[] started");
            byte[] buffer = new byte[s.Length / 2];
            try
            {
                s = s.Replace(" ", "");

                for (int i = 0; i < s.Length; i += 2)
                    buffer[i / 2] = Convert.ToByte(s.Substring(i, 2), 16);

            }
            catch (Exception ex)
            {
                logger.Error($"Error at HexStringToByteArray", ex);
            }
            logger.Info($"Converstion from Hex to Byte[] completed");
            return buffer;
        }

        public decimal? ProcessResponseString(string response, Channel channel)
        {
            logger.Info($"Processing started");
            decimal? value = null;
            try
            {
                logger.Info($"Splitting response from string to array of string using delimeter ' ' ");
                string[] outputarry = response.Split(' ');
                logger.Info($"Splittig completed");
                logger.Info($"Combinig {channel.ValuePosition} and {channel.ValuePosition + 1} Positions of string array");
                string combinedValue = outputarry[(int)channel.ValuePosition] + outputarry[(int)channel.ValuePosition + 1];
                logger.Info($"Combined string : {combinedValue}");
                logger.Info($"Converting hexstring to 32Bit Integer");
                decimal decValue = Convert.ToInt32(combinedValue, 16);
                logger.Info($"Converted value : {decValue}");
                logger.Info($"Converting to decimal");
                value = Convert.ToDecimal(decValue);
                logger.Info($"Converted value : {value}");
            }
            catch (Exception ex)
            {
                logger.Error($"Error at ProcessResponseString", ex);
            }
            logger.Info($"Processing completed");
            return value;//return the value.
        }

        public string SerialPortWriteAndReceiveResponse(string command, string comport, int baudrate)
        {
            string response = string.Empty;//intitializing empty response string.
            logger.Info($"Comport communication Started");
            using (SerialPort serialPort = new SerialPort(comport, baudrate, Parity.None, 8, StopBits.One))//creating serialport instance.
            {
                try
                {
                    if (!serialPort.IsOpen)
                    {
                        serialPort.Open();
                    }
                    logger.Info($"Comport : {comport} Opened");
                    logger.Info($"Converting commmand from Hex to Byte[] : {command}");
                    byte[] dataToSend = HexStringToByteArray(command);
                    logger.Info($"Command Bytes : {string.Join(",",dataToSend)}");
                    logger.Info($"Writing command bytes to comport");
                    serialPort.Write(dataToSend, 0, dataToSend.Length);
                    logger.Info($"Writing Completed");
                    serialPort.ReadTimeout = 5000;
                    byte[] buffer = new byte[1024];
                    logger.Info($"Sleeping thread for 5 seconds");
                    Thread.Sleep(5000);
                    logger.Info($"Reading response from comport");
                    int bytesRead = serialPort.Read(buffer, 0, buffer.Length);
                    logger.Info($"{bytesRead} Bytes read from comport");
                    logger.Info($"Converting Bytes to string");
                    response = ByteArrayToHexString(buffer);
                    logger.Info($"Converted response : {response}");
                }
                catch (Exception ex)
                {

                    logger.Error($"Error at SerialPortWriteAndReceiveResponse", ex);
                }
                finally
                {
                    if (serialPort.IsOpen)
                    {
                        serialPort.Close();
                    }
                    logger.Info($"Comport : {comport} Closed");
                }
                logger.Info($"Comport communication Started");
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

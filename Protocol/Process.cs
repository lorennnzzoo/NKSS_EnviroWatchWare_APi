using log4net;
using log4net.Config;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Protocol
{
    public class Process
    {
        private static readonly ILog logger = LogManager.GetLogger(typeof(Process));
        public Process()
        {
            XmlConfigurator.Configure(new System.IO.FileInfo("log4net.config"));
        }
        public static decimal? FetchAnalyzerValue(Models.Analyzer analyzer,Models.Channel channel)
        {
            decimal? value = null;
            logger.Info($"Fetching value for : {analyzer.ProtocolType}");
            logger.Info($"Checking if the protocol exists");
            if (Mapper.ProtocolDictionary.TryGetValue(analyzer.ProtocolType.ToUpper(), out var method))
            {
                logger.Info("Protocol found");
                logger.Info($"Communication Type : {analyzer.CommunicationType}");
                if (analyzer.CommunicationType.ToUpper() == "C")
                {
                    logger.Info($"Comport : {analyzer.ComPort} Baudrate : {analyzer.BaudRate} StopBits : {analyzer.StopBits} DataBits : {analyzer.DataBits} Parity : {analyzer.Parity}");
                }
                else
                {
                    logger.Info($"IpAddress : {analyzer.IpAddress} Port : {analyzer.Port}");
                }
                logger.Info($"Command : {analyzer.Command}");
                
                value = method(analyzer,channel);
                if (value.HasValue)
                {
                    logger.Info($"Value : {value}");
                }
                else
                {
                    logger.Warn($"Value is null");
                }
            }
            else
            {
                logger.Warn($"No mathing protocol found for : {analyzer.ProtocolType}");
            }
            return value;
        }
    }
}

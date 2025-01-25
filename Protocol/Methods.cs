using log4net;
using log4net.Config;
using Models;
using Protocol.Interfaces;
using Protocol.RS485;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Protocol
{
    public class Methods
    {
        private static readonly ILog logger = LogManager.GetLogger(typeof(Methods));
        public Methods()
        {
            XmlConfigurator.Configure(new System.IO.FileInfo("log4net.config"));
        }

        private static decimal? ProcessProtocolData(IProtocol protocol, Analyzer analyzer,Channel channel)
        {
            decimal? value = null;
            try
            {
                logger.Info($"Fetching data");
                string data = GetExternalData(protocol, analyzer, channel);
                
                if (!string.IsNullOrEmpty(data))
                {
                    logger.Info($"Received response : {data}");
                    value = protocol.GetDataFromResponse(data, channel);
                }
                else
                {
                    logger.Warn($"Empty response received");                   
                }
            }
            catch (Exception ex)
            {
                logger.Error("Error at ProcessProtocolData", ex);
            }
            return value;
        }
        private static string GetExternalData(IProtocol protocol, Analyzer analyzer,Channel channel)
        {
            logger.Info($"Fetching started");
            string data = string.Empty;
            data = protocol.ConnectToModuleAndGetResponse(analyzer);
            logger.Info($"Fetching completed");
            return data;
        }
       
        public static decimal? GetDataFromRS485Integer(Analyzer analyzer,Channel channel)
        {
            logger.Info($"RS485INTEGER Started");
            INTEGER protocol = new INTEGER();
            return ProcessProtocolData(protocol, analyzer, channel);
        }
    }
}

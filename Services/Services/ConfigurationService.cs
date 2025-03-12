using Repositories.Interfaces;
using Services.Interfaces;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services
{
    public class ConfigurationService : IConfigurationService
    {
        private readonly IConfigurationRepository _configurationRepository;
        public ConfigurationService(IConfigurationRepository configurationRepository)
        {
            _configurationRepository = configurationRepository;
        }
        public Dictionary<string, object> GetConfiguration()
        {
            System.Data.DataSet dataSet = _configurationRepository.GetConfigurationDataSet();
            var configuration = new Dictionary<string, object>
                                        {
                                            { "Configuration", new Dictionary<string, object>() }
                                        };
            if (dataSet.Tables.Count > 0)
            {
                

                var configurationElement = (Dictionary<string, object>)configuration["Configuration"];

                
                var companies = new List<Dictionary<string, object>>();
                foreach (DataRow companyRow in dataSet.Tables[0].Rows)
                {
                    var companyElement = new Dictionary<string, object>();

                    
                    foreach (DataColumn column in dataSet.Tables[0].Columns)
                    {
                        companyElement[column.ColumnName] = ConvertValueBasedOnType(companyRow[column], column.DataType);
                    }

                    
                    var stations = new List<Dictionary<string, object>>();
                    foreach (DataRow stationRow in dataSet.Tables[1].Rows)
                    {
                        if (stationRow.Field<int>("CompanyId") == companyRow.Field<int>("Id"))
                        {
                            var stationElement = new Dictionary<string, object>();

                            
                            foreach (DataColumn column in dataSet.Tables[1].Columns)
                            {
                                stationElement[column.ColumnName] = ConvertValueBasedOnType(stationRow[column], column.DataType);
                            }

                            
                            var monitoringTypes = new List<Dictionary<string, object>>();
                            foreach (DataRow monitoringTypeRow in dataSet.Tables[3].Rows)
                            {
                                if (monitoringTypeRow.Field<int>("Id") == stationRow.Field<int>("MonitoringTypeId"))
                                {
                                    var monitoringTypeElement = new Dictionary<string, object>();
                                    foreach (DataColumn column in dataSet.Tables[3].Columns)
                                    {
                                        monitoringTypeElement[column.ColumnName] = ConvertValueBasedOnType(monitoringTypeRow[column], column.DataType);
                                    }
                                    monitoringTypes.Add(monitoringTypeElement);
                                }
                            }
                            stationElement["MonitoringType"] = monitoringTypes;

                            
                            var channels = new List<Dictionary<string, object>>();
                            foreach (DataRow channelRow in dataSet.Tables[2].Rows)
                            {
                                if (channelRow.Field<int>("StationId") == stationRow.Field<int>("Id"))
                                {
                                    var channelElement = new Dictionary<string, object>();

                                    
                                    foreach (DataColumn column in dataSet.Tables[2].Columns)
                                    {
                                        channelElement[column.ColumnName] = ConvertValueBasedOnType(channelRow[column], column.DataType);
                                    }

                                    
                                    var analyzers = new List<Dictionary<string, object>>();
                                    foreach (DataRow analyzerRow in dataSet.Tables[6].Rows)
                                    {
                                        if (analyzerRow.Field<int>("Id") == channelRow.Field<int>("ProtocolId"))
                                        {
                                            var analyzerElement = new Dictionary<string, object>();
                                            foreach (DataColumn column in dataSet.Tables[6].Columns)
                                            {
                                                analyzerElement[column.ColumnName] = ConvertValueBasedOnType(analyzerRow[column], column.DataType);
                                            }
                                            analyzers.Add(analyzerElement);
                                        }
                                    }
                                    channelElement["Analyzer"] = analyzers;

                                    
                                    var oxides = new List<Dictionary<string, object>>();
                                    foreach (DataRow oxideRow in dataSet.Tables[5].Rows)
                                    {
                                        if (oxideRow.Field<int>("Id") == channelRow.Field<int>("OxideId"))
                                        {
                                            var oxideElement = new Dictionary<string, object>();
                                            foreach (DataColumn column in dataSet.Tables[5].Columns)
                                            {
                                                oxideElement[column.ColumnName] = ConvertValueBasedOnType(oxideRow[column], column.DataType);
                                            }
                                            oxides.Add(oxideElement);
                                        }
                                    }
                                    channelElement["Oxide"] = oxides;

                                    
                                    var channelTypes = new List<Dictionary<string, object>>();
                                    foreach (DataRow channelTypeRow in dataSet.Tables[4].Rows)
                                    {
                                        if (channelTypeRow.Field<int>("Id") == channelRow.Field<int>("ChannelTypeId"))
                                        {
                                            var channelTypeElement = new Dictionary<string, object>();
                                            foreach (DataColumn column in dataSet.Tables[4].Columns)
                                            {
                                                channelTypeElement[column.ColumnName] = ConvertValueBasedOnType(channelTypeRow[column], column.DataType);
                                            }
                                            channelTypes.Add(channelTypeElement);
                                        }
                                    }
                                    channelElement["ChannelType"] = channelTypes;

                                    
                                    var scalingFactors = new List<Dictionary<string, object>>();
                                    foreach (DataRow scalingFactorRow in dataSet.Tables[7].Rows)
                                    {
                                        if (scalingFactorRow.Field<int>("Id") == channelRow.Field<int>("ScalingFactorId"))
                                        {
                                            var scalingFactorElement = new Dictionary<string, object>();
                                            foreach (DataColumn column in dataSet.Tables[7].Columns)
                                            {
                                                scalingFactorElement[column.ColumnName] = ConvertValueBasedOnType(scalingFactorRow[column], column.DataType);
                                            }
                                            scalingFactors.Add(scalingFactorElement);
                                        }
                                    }
                                    channelElement["ScalingFactor"] = scalingFactors;

                                    channels.Add(channelElement);
                                }
                            }
                            stationElement["Channels"] = channels;

                            stations.Add(stationElement);
                        }
                    }
                    companyElement["Stations"] = stations;

                    companies.Add(companyElement);
                }
                configurationElement["Companies"] = companies;

                
                var licenses = new List<Dictionary<string, object>>();
                foreach (DataRow licenseRow in dataSet.Tables[8].Rows)
                {
                    var licenseElement = new Dictionary<string, object>();
                    foreach (DataColumn column in dataSet.Tables[8].Columns)
                    {
                        licenseElement[column.ColumnName] = ConvertValueBasedOnType(licenseRow[column], column.DataType);
                    }
                    licenses.Add(licenseElement);
                }
                configurationElement["Licenses"] = licenses;

                
                var configSettings = new List<Dictionary<string, object>>();
                foreach (DataRow configSettingRow in dataSet.Tables[9].Rows)
                {
                    var configSettingElement = new Dictionary<string, object>();
                    foreach (DataColumn column in dataSet.Tables[9].Columns)
                    {
                        configSettingElement[column.ColumnName] = ConvertValueBasedOnType(configSettingRow[column], column.DataType);
                    }
                    configSettings.Add(configSettingElement);
                }
                configurationElement["ConfigSettings"] = configSettings;

            }
                return configuration;
        }
        private static object ConvertValueBasedOnType(object value, Type type)
        {
            if (value == DBNull.Value)
                return null;

            if (type == typeof(int) || type == typeof(long) || type == typeof(short))
                return Convert.ToInt64(value);

            if (type == typeof(decimal) || type == typeof(float) || type == typeof(double))
                return Convert.ToDecimal(value);

            if (type == typeof(DateTime))
                return Convert.ToDateTime(value).ToString("yyyy-MM-ddTHH:mm:ss");

            if (type == typeof(bool))
                return Convert.ToBoolean(value);

            return value.ToString(); 
        }
    }
}

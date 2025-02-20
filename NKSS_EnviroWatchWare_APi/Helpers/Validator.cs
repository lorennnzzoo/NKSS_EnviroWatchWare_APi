using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace NKSS_EnviroWatchWare_APi.Helpers
{
    public class Validator
    {
        public virtual (bool isValid, string errorMessage) ValidateProperties(object obj)
        {
            if (obj == null) return (false, "Request body cannot be null.");

            var communicationType = obj.GetType().GetProperty("CommunicationType")?.GetValue(obj)?.ToString();

            var nullProperties = obj.GetType()
                                    .GetProperties()
                                    .Where(prop =>
                                        prop.GetValue(obj) == null &&
                                        (communicationType != "C" || !IsIgnoredForCommunicationTypeC(prop.Name)) &&
                                        (communicationType != "IP" || !IsIgnoredForCommunicationTypeIP(prop.Name))
                                    )
                                    .Select(prop => prop.Name)
                                    .ToList();

            if (!nullProperties.Any())
            {
                return (true, string.Empty); 
            }

            if (nullProperties.Count == 1)
            {
                return (false, $"{nullProperties.First()} cannot be null.");
            }

            string propertyList = string.Join(", ", nullProperties);
            return (false, $"{propertyList} cannot be null.");
        }

        private bool IsIgnoredForCommunicationTypeC(string propertyName)
        {
            return propertyName == "IpAddress" || propertyName == "Port";
        }

        private bool IsIgnoredForCommunicationTypeIP(string propertyName)
        {
            return propertyName == "ComPort" || propertyName == "BaudRate" || propertyName == "Parity" || propertyName == "DataBits" || propertyName == "StopBits";
        }

    }

}
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace NKSS_EnviroWatchWare_APi.Helpers
{
    public class ChannelValidator:Validator
    {
        public override (bool isValid, string errorMessage) ValidateProperties(object obj)
        {
            if (obj == null) return (false, "Request body cannot be null.");

            // Exclude specific properties from validation
            var excludedProperties = new HashSet<string> { "ScalingFactorId" };

            var nullProperties = obj.GetType()
                                    .GetProperties()
                                    .Where(prop => !excludedProperties.Contains(prop.Name) && prop.GetValue(obj) == null)
                                    .Select(prop => prop.Name)
                                    .ToList();

            if (!nullProperties.Any())
            {
                return (true, string.Empty); // All properties are valid
            }

            if (nullProperties.Count == 1)
            {
                return (false, $"{nullProperties.First()} cannot be null.");
            }

            string propertyList = string.Join(", ", nullProperties);
            return (false, $"{propertyList} cannot be null.");
        }

    }
}
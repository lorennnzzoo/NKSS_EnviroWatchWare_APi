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

            var nullProperties = obj.GetType()
                                    .GetProperties()
                                    .Where(prop => prop.GetValue(obj) == null)
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
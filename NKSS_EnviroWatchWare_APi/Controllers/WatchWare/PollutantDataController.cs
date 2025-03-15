using Models.PollutionData;
using NKSS_EnviroWatchWare_APi.Providers;
using Services;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web;
using System.Web.Http;
using System.Web.Http.Cors;

namespace NKSS_EnviroWatchWare_APi.Controllers.WatchWare
{
    [DisableCors]
    [PollutantAuthorize]    
    [RoutePrefix("PollutantData")]
    public class PollutantDataController : ApiController
    {
        private readonly PollutionDataService pollutionDataService;
        public PollutantDataController(PollutionDataService _pollutionDataService)
        {
            pollutionDataService = _pollutionDataService;
        }
        [HttpPost]
        [Route("Upload")]
        public IHttpActionResult Upload(PollutantDataUploadRequest Request)
        {            
            try
            {
                string authHeader = HttpContext.Current.Request.Headers["Authorization"];                
                bool success = pollutionDataService.ImportData(authHeader,Request);
                if (success)
                {
                    return Ok("Data inserted successfully.");
                }
                else
                {
                    return BadRequest("Insertion failed.");
                }                
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.BadRequest)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }

        [OverrideAuthorization]
        [Authorize]
        [HttpPost]
        [Route("UploadBulk")]
        public IHttpActionResult UploadBulk()
        {
            try
            {               
                if (!Request.Content.IsMimeMultipartContent())
                {
                    throw new Exception("Unsupported MediaType.");
                }

                var provider = new MultipartMemoryStreamProvider();
                Request.Content.ReadAsMultipartAsync(provider).Wait();

                if (provider.Contents.Count != 1)
                {
                    throw new Exception("Only one file is allowed per request.");
                }

                var fileContent = provider.Contents.First();
                var fileName = fileContent.Headers.ContentDisposition.FileName?.Trim('\"');

                
                if (string.IsNullOrEmpty(fileName) || !fileName.EndsWith(".csv", StringComparison.OrdinalIgnoreCase))
                {
                    throw new Exception("Only CSV files are allowed.");
                }

                
                const int maxFileSize = 50 * 1024 * 1024; 
                if (fileContent.Headers.ContentLength.HasValue && fileContent.Headers.ContentLength.Value > maxFileSize)
                {
                    throw new Exception("File size exceeds the 50MB limit.");
                }

                
                var fileType = fileContent.Headers.ContentType?.MediaType;
                if (fileType != "text/csv" && fileType != "application/vnd.ms-excel")
                {
                    throw new Exception("Invalid file type. Only CSV files are allowed.");
                }

                using (var stream = fileContent.ReadAsStreamAsync().Result)
                using (var reader = new StreamReader(stream))
                {
                    var lines = new List<string>();
                    string line;
                    while ((line = reader.ReadLine()) != null)
                    {
                        lines.Add(line.Trim());
                    }

                    
                    if (lines.Count == 0)
                    {
                        throw new Exception("No data found in the file.");
                    }

                    
                    const string expectedHeader = "ChannelId,Value,LogTime";
                    if (!lines[0].Equals(expectedHeader, StringComparison.OrdinalIgnoreCase))
                    {
                        throw new Exception($"Invalid CSV format. Expected header: {expectedHeader}");
                    }

                    
                    if (lines.Count == 1)
                    {
                        throw new Exception("No records found after the header.");
                    }
                    pollutionDataService.ImportBulkData(lines);
                }
                
                return Ok("File uploaded successfully.");
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }
    }
}

import asyncio
import aiohttp
import time
import pandas as pd
from datetime import datetime

URL = "https://tms2-1.onrender.com/"
VIRTUAL_USERS = 100
DURATION_SECONDS = 60

results = []

async def fetch(session, user_id):
    end_time = time.time() + DURATION_SECONDS
    while time.time() < end_time:
        start_req = time.time()
        try:
            async with session.get(URL) as response:
                await response.read()
                status = response.status
        except Exception as e:
            status = "Error"
        
        duration = time.time() - start_req
        results.append({
            "timestamp": datetime.now(),
            "user_id": user_id,
            "duration_ms": duration * 1000,
            "status_code": status
        })

async def main():
    print(f"Starting load test on {URL} with {VIRTUAL_USERS} users for {DURATION_SECONDS} seconds...")
    async with aiohttp.ClientSession() as session:
        tasks = []
        for i in range(VIRTUAL_USERS):
            tasks.append(fetch(session, i))
        
        await asyncio.gather(*tasks)

if __name__ == "__main__":
    start_time = time.time()
    asyncio.run(main())
    total_time = time.time() - start_time
    
    print(f"Load test completed in {total_time:.2f} seconds.")
    
    df = pd.DataFrame(results)
    
    if len(df) == 0:
        print("No requests were successful.")
        exit()
        
    total_requests = len(df)
    successful_requests = len(df[df['status_code'] == 200])
    failed_requests = total_requests - successful_requests
    
    avg_response_time = df['duration_ms'].mean()
    min_response_time = df['duration_ms'].min()
    max_response_time = df['duration_ms'].max()
    
    rps = total_requests / DURATION_SECONDS
    
    print(f"Total Requests: {total_requests}")
    print(f"Successful Requests: {successful_requests}")
    print(f"Failed Requests: {failed_requests}")
    print(f"Requests per Second (RPS): {rps:.2f}")
    print(f"Average Response Time: {avg_response_time:.2f} ms")
    print(f"Min Response Time: {min_response_time:.2f} ms")
    print(f"Max Response Time: {max_response_time:.2f} ms")
    
    summary_data = {
        "Metric": ["Target URL", "Virtual Users", "Duration (seconds)", "Total Requests", "Successful Requests", "Failed Requests", "Requests per Second (RPS)", "Average Response Time (ms)", "Min Response Time (ms)", "Max Response Time (ms)"],
        "Value": [URL, VIRTUAL_USERS, DURATION_SECONDS, total_requests, successful_requests, failed_requests, round(rps, 2), round(avg_response_time, 2), round(min_response_time, 2), round(max_response_time, 2)]
    }
    summary_df = pd.DataFrame(summary_data)
    
    excel_filename = f"Load_Test_Report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.xlsx"
    with pd.ExcelWriter(excel_filename, engine='openpyxl') as writer:
        summary_df.to_excel(writer, sheet_name="Summary", index=False)
        df.to_excel(writer, sheet_name="Raw Data", index=False)
        
    print(f"Report saved to {excel_filename}")
